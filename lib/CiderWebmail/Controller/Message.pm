package CiderWebmail::Controller::Message;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Message;
use MIME::Lite;
use MIME::Words qw(encode_mimeword);
use Clone qw(clone);
use List::Util qw(first);

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
    $c->stash->{message} = CiderWebmail::Message->new($c, { mailbox => $c->stash->{folder}, uid => $uid } );
}


=head2 view 

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $message = $c->stash->{message};
    my $uid = $message->uid;
    
    $message->load_body();

    foreach my $id (keys(%{ $message->{attachments} })) {
        $message->{attachments}->{$id}->{uri_view} = $c->uri_for('/mailbox/' . $c->stash->{folder} . '/' . $message->uid . "/attachment/$id");
    }

    $message->mark_read();

    $c->stash({
        template        => 'message.xml',
        target_folders  => [ sort {($a->{name} or '') cmp ($b->{name} or '')} values %{ clone($c->stash->{folders_hash}) } ],
        uri_view_source => $c->uri_for("/mailbox/$mailbox/$uid/view_source"),
        uri_reply       => $c->uri_for("/mailbox/$mailbox/$uid/reply/sender"),
        uri_reply_all   => $c->uri_for("/mailbox/$mailbox/$uid/reply/all"),
        uri_forward     => $c->uri_for("/mailbox/$mailbox/$uid/forward"),
        uri_move        => $c->uri_for("/mailbox/$mailbox/$uid/move"),
    });
}

=head2 attachment

=cut

sub attachment : Chained('setup') Args(1) {
    my ( $self, $c, $id ) = @_;

    my $mailbox = $c->stash->{folder};

    my $attachment = $c->stash->{message}->attachments->{$id};

    $c->res->content_type($attachment->{type});
    $c->res->header('content-disposition' => ($c->res->headers->content_is_html ? 'inline' : 'attachment') . "; filename=$attachment->{name}");
    $c->res->body($attachment->{data});
}

=head2 view_source

=cut

sub view_source : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $message = $c->stash->{message};
    my $uid = $message->uid;

    $c->res->content_type('text/plain');
    $c->res->body($c->model('IMAPClient')->message_as_string($c, { mailbox => $mailbox, uid => $uid }));
}

=head2 delete

Move a message to the trash (if available) or delete a message from the trash.

=cut

sub delete : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;

    my $folders = $c->stash->{folders_hash};
    my $trash = first { $_ =~ /\btrash|papierkorb\b/i } keys %$folders; # try to find a folder called "Trash"

    if ($trash and $c->stash->{folder} ne $trash) {
        $c->stash->{message}->move({target_folder => $trash});
    }
    else {
        $c->stash->{message}->delete();
    }
    
    CiderWebmail::Util::send_foldertree_update($c); # update folder display
}

=head2 move

Move a message to a different folder

=cut

sub move : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $target_folder = $c->req->param('target_folder') or die "no folder to move message to";

    $c->stash->{message}->move({target_folder => $target_folder});

    CiderWebmail::Util::send_foldertree_update($c); # update folder display
}

=head2 compose

Compose a new message for sending

=cut

sub compose : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{message} ||= {};

    my $settings = $c->model('DB::Settings')->find($c->user->id);
    $c->stash->{message}{from} = [ Mail::Address->parse($settings->from_address) ] if $settings and $settings->from_address;

    my $folders = clone($c->stash->{folders_hash});
    delete $_->{selected} foreach values %$folders; # clean any selectedness

    if ($settings and $settings->sent_folder and exists $folders->{$settings->sent_folder}) {
        $folders->{$settings->sent_folder}{selected} = 'selected';
    }
    else {
        my $sent = first { $_ =~ /\bsent\b/i } keys %$folders; # try to find a folder called "Sent"
        $folders->{$sent}{selected} = 'selected' if $sent;
    }

    $c->stash({
        uri_send     => $c->uri_for('/mailbox/' . $c->stash->{folder} . '/send'),
        sent_folders => [ sort {($a->{name} or '') cmp ($b->{name} or '')} values %$folders ],
        template     => 'compose.xml',
    });
}

=head2 reply

Reply to a message suggesting receiver, subject and message text

=cut

sub reply : Chained('setup') Args(1) {
    my ( $self, $c, $who ) = @_;
    my $mailbox = $c->stash->{folder};
    my $message = $c->stash->{message};

    #FIXME: we need a way to find the 'main part' of a message and use this here
    my $body = $message->main_body_part($c);
    $body =~ s/[\s\r\n]+\z//s;
    $body =~ s/^/> /gm;
    $body .= "\n\n";

    my $new_message = {
        from    => $message->to, # If no user-specified from address is available, the to address of the replied-to mail is a good guess
        subject => 'Re: ' . $message->subject,
        body    => $body,
    };

    if ($who eq 'sender') {
        my $recipient = ($message->reply_to or $message->from);
        $new_message->{to} = $recipient->[0]->address;
    } elsif ($who eq 'all') {
        my @recipients;
        foreach( ( ( $message->reply_to or $message->from ), $message->cc, $message->to ) ) {
            push(@recipients, $_->address) foreach( @$_ );
        }
        $new_message->{to} = join('; ', @recipients);
    } else {
        die("invalid reply destination");
    }

    $c->stash(message => $new_message);

    $c->forward('compose');
}

=head2 forward

Forward a mail as attachment

=cut

sub forward : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $message = $c->stash->{message};

    $c->stash({
        forward => $message->uid,
        message => {
            from    => $message->to,
            subject => 'Fwd: ' . $message->subject,
        },
    });

    $c->forward('compose');
}

=head2 send

Send a mail

=cut

sub send : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    my $subject = encode_mimeword($c->req->param('subject'));
    my $body = $c->req->param('body');
    utf8::encode($body);
    my $from = $c->req->param('from');
    my $sent_folder = $c->req->param('sent_folder');

    my $settings = $c->model('DB::Settings');
    $settings->update_or_create({
        user => $c->user->id,
        from_address => $from,
        sent_folder => $sent_folder
    });

    my $mail = MIME::Lite->new(
        From    => $from,
        To      => $c->req->param('to'),
        ($c->req->param('cc') ? (Cc => $c->req->param('cc')) : ()),
        Subject => $subject,
        Data    => $body,
    );

    $mail->attr("content-type"         => "text/plain");
    $mail->attr("content-type.charset" => 'UTF-8');

    if (my $attachment = $c->req->param('attachment')) {
        my $upload = $c->req->upload('attachment');
        $mail->attach(
            Type        => $upload->type,
            Filename    => $upload->basename,
            FH          => $upload->fh,
            Disposition => 'attachment',
        );
    }

    if (my $forward = $c->req->param('forward')) {
        my $mailbox = $c->stash->{folder};
        my $message = CiderWebmail::Message->new($c, { mailbox => $mailbox, uid => $forward } );

        $mail->attach(
            Type     => 'message/rfc822',
            Filename => $message->subject . '.eml',
            Data     => $message->as_string,
        );
    }

    $mail->send;

    if ($sent_folder) {
        my $msg_text = $mail->as_string;
        $c->model('IMAPClient')->append_message($c, {mailbox => $sent_folder, message_text => $msg_text});
    }

    $c->res->redirect($c->uri_for('/mailbox/' . $c->stash->{folder}));
}

=head1 AUTHOR

,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
