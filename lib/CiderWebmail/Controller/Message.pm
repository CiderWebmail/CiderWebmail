package CiderWebmail::Controller::Message;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Message;
use CiderWebmail::Util;

use Encode;
use MIME::Entity;

use Try::Tiny;

use DateTime;
use DateTime::Format::Mail;
use Email::Valid;

use Email::Sender::Simple qw/sendmail/;
use Email::Sender::Transport::Sendmail;
use Email::Sender::Transport::SMTP;

use Clone qw(clone);
use List::Util qw(first);
use List::MoreUtils qw(all);

use Carp qw/ croak /;

=head1 NAME

CiderWebmail::Controller::Message - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 setup

Gets the selected message from the URI path and sets up the stash.

=cut

sub setup : Chained('/mailbox/setup') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $uid ) = @_;

    $c->stash->{message} = CiderWebmail::Message->new(c => $c, mailbox => $c->stash->{folder}, uid => $uid);

    return;
}


=head2 view 

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    my $uri_folder = $c->stash->{uri_folder};
    my $message    = $c->stash->{message};
    my $uid = $message->uid;
    
    $message->mark_read();

    CiderWebmail::Util::send_foldertree_update($c); # update folder display

    $c->stash({
        template                => 'message.xml',
        target_folders          => [ sort {($a->{name} or '') cmp ($b->{name} or '')} values %{ clone($c->stash->{folders_hash}) } ],
        uri_view_source         => "$uri_folder/$uid/view_source",
        uri_reply               => "$uri_folder/$uid/part/reply/sender",
        uri_reply_all           => "$uri_folder/$uid/part/reply/all",
        uri_forward             => "$uri_folder/$uid/part/forward",
        uri_get_header          => "$uri_folder/$uid/part/header",
        uri_move                => "$uri_folder/$uid/move",
        uri_toggle_important    => "$uri_folder/$uid/toggle_important",
    });

    return;
}

=head2 download attachment 

=cut

sub download_attachment : Chained('setup') PathPart('part/download') Args {
    my ( $self, $c, $part_id ) = @_;

    my $part = $c->stash->{message}->get_part_by_part_id({ part_id => $part_id });

    $c->res->content_type($part->content_type);

    $c->res->header('content-disposition' => 'attachment' . "; filename=".($part->file_name or 'unknown'));

    return $c->res->body($part->body({ raw => 1 }));
}

=head2 render part

=cut

sub render_part : Chained('setup') PathPart('part/render') Args {
    my ( $self, $c, $part_id ) = @_;

    my $part = $c->stash->{message}->get_part_by_part_id({ part_id => $part_id });

    return $c->res->body($part->render);
}


=head2 download header

=cut

sub download_header : Chained('setup') PathPart('part/header') Args {
    my ( $self, $c, $part_id ) = @_;

    my $part = $c->stash->{message}->get_part_by_part_id({ part_id => $part_id });

    $c->res->content_type('text/plain');
    return $c->res->body($part->header);
}


=head2 view_source

=cut

sub view_source : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $message = $c->stash->{message};
    my $uid = $message->uid;

    $c->res->content_type('text/plain');
    return $c->res->body($c->model('IMAPClient')->message_as_string({ mailbox => $mailbox, uid => $uid }));
}

=head2 toggle_important

toggle the important/flagged IMAP flag, send the new flag icon to the client.

=cut

sub toggle_important : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $message = $c->stash->{message};

    my $new_status = $message->toggle_important;

    if (($c->req->header('X-Request') or '') eq 'AJAX') {
        $c->res->content_type('text/plain');
        return $c->res->body($new_status 
            ? $c->uri_for('/static/images/flag-red.png')
            : $c->uri_for('/static/images/flag.png')
        );
    } else {
        $c->forward('view');
    }
}


=head2 delete

Move a message to the trash (if available) or delete a message from the trash.

=cut

sub delete : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;

    #create the foldertree so we can find the trash folder
    CiderWebmail::Util::add_foldertree_to_stash($c);
    
    my $folders = $c->stash->{folders_hash};
    my $trash = first { $_ =~ /\b trash | papierkorb \b/ixm } keys %$folders; # try to find a folder called "Trash"

    if ($trash and $c->stash->{folder} ne $trash) {
        $c->stash->{message}->move({target_folder => $trash});
    }
    else {
        $c->stash->{message}->delete();
    }
    
    #update the foldertree after we deleted the message because the foldertree changed
    delete $c->stash->{folder_tree};
    CiderWebmail::Util::add_foldertree_to_stash($c);

    return ($c->req->header('X-Request') or '') eq 'AJAX'
        ? CiderWebmail::Util::send_foldertree_update($c) # update folder display
        : $c->res->redirect($c->stash->{uri_folder});
}

=head2 move

Move a message to a different folder

=cut

sub move : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $target_folder = $c->req->param('target_folder') or croak("no folder to move message to");

    $c->stash->{message}->move({target_folder => $target_folder});

    return ($c->req->header('X-Request') or '') eq 'AJAX'
        ? CiderWebmail::Util::send_foldertree_update($c) # update folder display
        : $c->res->redirect($c->stash->{uri_folder});
}

=head2 compose

Compose a new message for sending

=cut

sub compose : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{message} ||= {};

    if ($c->req->param('to') && Email::Valid->address($c->req->param('to'))) {
        $c->stash->{message}{to} = $c->req->param('to');
    }

    CiderWebmail::Util::add_foldertree_to_stash($c);

    my $settings = $c->model('DB::Settings')->find($c->user->id);

    if ($settings and $settings->from_address) {
        $c->stash->{message}{from} = [ Mail::Address->parse($settings->from_address) ];
    }
    elsif ($c->config->{username_default_address}) {
        $c->stash->{message}{from} = [ Mail::Address->parse($c->session->{username}) ]
    }

    my $folders = clone($c->stash->{folders_hash});
    delete $_->{selected} foreach values %$folders; # clean any selectedness

    if ($settings and $settings->sent_folder and exists $folders->{$settings->sent_folder}) {
        $folders->{$settings->sent_folder}{selected} = 'selected';
    }
    else {
        my $sent = first { $_ =~ /\b (?: sent | outbox |gesendete? ) \b/ixm } sort keys %$folders; # try to find a folder called "Sent"
        $folders->{$sent}{selected} = 'selected' if $sent;
    }

    $c->stash({
        uri_send     => $c->stash->{uri_folder} . '/send',
        sent_folders => [ sort {($a->{name} or '') cmp ($b->{name} or '')} values %$folders ],
        template     => 'compose.xml',
    });

    return;
}

=head2 reply

Reply to a message suggesting receiver, subject and message text

=cut

sub reply : Chained('setup') PathPart('part/reply') Args() {
    my ( $self, $c, $who, $part_id ) = @_;
    my $message = $c->stash->{message};

    my $part = $c->stash->{message}->get_part_by_part_id({ part_id => $part_id });

    #FIXME: we need a way to find the 'main part' of a message and use this here
    my $body = $part->main_body_part->body;
    if ($body) {
        $body =~ s/[\s\r\n]+ \z//sxm;
        $body =~ s/^/> /gxm;
        $body .= "\n\n";
    }

    my $new_message = {
        from    => $part->guess_recipient, # If no user-specified from address is available, the to address of the replied-to mail is a good guess
        subject => 'Re: ' . $message->subject,
        body    => $body,
    };

    my @recipients;

    if ($who eq 'sender') {
        my $reply_to = $part->reply_to;
        my $recipient = (($reply_to and @$reply_to) ? $reply_to : $part->from);
        @recipients = $recipient->[0]->address if @$recipient and $recipient->[0];
    } elsif ($who eq 'all') {
        foreach( ( ( $part->reply_to or $part->from ), $part->cc, $part->to ) ) {
            push(@recipients, $_->address) foreach( @$_ );
        }
    } else {
        croak("invalid reply destination");
    }

    $new_message->{to} = join('; ', CiderWebmail::Util::filter_unusable_addresses(@recipients));

    $c->stash({
        in_reply_to => $part,
        message  => $new_message,
    });

    $c->forward('compose');

    return;
}

=head2 forward

Forward a mail as attachment

=cut

sub forward : Chained('setup') PathPart('part/forward') Args() {
    my ( $self, $c, $part_id ) = @_;
    my $message = $c->stash->{message};

    my $part = $c->stash->{message}->get_part_by_part_id({ part_id => $part_id });

    $c->stash({
        forward => $part,
        message => {
            from    => $part->guess_recipient,
            subject => 'Fwd: ' . $part->subject,
        },
    });

    $c->forward('compose');

    return;
}

=head2 send

Send a mail

=cut

sub send : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    my $subject = Encode::encode('MIME-Header', $c->req->param('subject'));
    my $body_content = $c->req->param('body');
    utf8::encode($body_content);
    my $from = $c->req->param('from');
    my $sent_folder = $c->req->param('sent_folder');

    my $settings = $c->model('DB::Settings');
    $settings->update_or_create({
        user => $c->user->id,
        from_address => $from,
        sent_folder => $sent_folder
    });

    #this is the top-level message we are going to send
    my $mail = MIME::Entity->build(
        Type        => 'multipart/mixed',
        From        => $from,
        To          => $c->req->param('to'),
        Date        => DateTime::Format::Mail->new->format_datetime(DateTime->now),
        ($c->req->param('cc') ? (Cc => $c->req->param('cc')) : ()),
        Subject     => $subject,
        'X-Mailer'  => "CiderWebmail ".$CiderWebmail::VERSION,
        Received    => "from " . ( defined $ENV{REMOTE_ADDR} ? $ENV{REMOTE_ADDR} : 'unknown REMOTE_ADDR' ) . " by " . ( defined $ENV{SERVER_NAME} ? $ENV{SERVER_NAME} : 'unknown SERVER_NAME' ) . " with HTTP;\n\t".DateTime::Format::Mail->new->format_datetime(DateTime->now),
    );

    #this is our main body - the text the user specified
    if (my $body_content = $c->req->param('body')) { #TODO decent check if we have a valid body? what if only forwarding as attachment etc?
        utf8::encode($body_content);
        my $body_entity = MIME::Entity->build(
            Type    => 'text/plain',
            Charset => 'UTF-8',
            Data    => $body_content,
        );

        $mail->add_part($body_entity);
    }

    if (my @attachments = $c->req->param('attachment')) {
        foreach ($c->req->upload('attachment')) {
            $mail->attach(
                Type        => $_->type,
                Filename    => $_->basename,
                Path        => $_->tempname,
                Disposition => 'attachment',
                ReadNow     => 1,
            );
        }
    }

    if (defined $c->req->param('forward')) {
        my ($uid, $part_id) = CiderWebmail::Util::parse_message_id($c->req->param('forward'));
        my $part_to_forward = CiderWebmail::Message->new(c => $c, mailbox => $c->stash->{folder}, uid => $uid)->get_part_by_part_id({ part_id => $part_id });

        $mail->attach(
            Type     => 'message/rfc822',
            Filename => $part_to_forward->subject . '.eml',
            Data     => $part_to_forward->body,
        );
    }

    if (defined $c->req->param('in_reply_to')) {
        my ($uid, $part_id) = CiderWebmail::Util::parse_message_id($c->req->param('in_reply_to'));
        my $in_reply_to_part = CiderWebmail::Message->new(c => $c, mailbox => $c->stash->{folder}, uid => $uid)->get_part_by_part_id({ part_id => $part_id });

        if ($in_reply_to_part) {
            if (my $message_id = $in_reply_to_part->message_id) {
                $mail->add('In-Reply-To', $message_id);
                my $references = $in_reply_to_part->references;
                $mail->add('References', join ' ', $references ? split /\s+/sxm, $references : (), $message_id);
            }

            $in_reply_to_part->mark_answered;
        } 
    }

    try {
        my $transport;

        #TODO add port and example to ciderwebmail.yml
        if (($c->config->{send}->{method} or '') eq 'smtp') {
            croak('smtp host not set') unless defined $c->config->{send}->{host};

            $transport = Email::Sender::Transport::SMTP->new({
                host => $c->config->{send}->{host},
                port => '25',
            });
        } else {
            $transport = Email::Sender::Transport::Sendmail->new();
        }

        sendmail($mail, { transport => $transport });
    } catch {
        $c->stash->{error} = $_;
        $c->detach('/error');
    };

    if ($sent_folder) {
        my $msg_text = $mail->as_string;
        $c->model('IMAPClient')->append_message({mailbox => $sent_folder, message_text => $msg_text});
    }

    return $c->res->redirect($c->stash->{uri_folder});
}

=head1 AUTHOR

,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
