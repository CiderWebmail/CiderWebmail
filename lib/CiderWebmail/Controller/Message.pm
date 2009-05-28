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
    my $uid = $c->stash->{message}->uid;
    
    $c->stash->{message}->load_body();

    foreach(keys(%{ $c->stash->{message}->{attachments} })) {
        my $id = $_;
        $c->stash->{message}->{attachments}->{$id}->{uri_view} = $c->uri_for('/mailbox/' . $c->stash->{folder} . '/' . $c->stash->{message}->uid . "/attachment/$id");
    }

    $c->stash->{message}->mark_read();

    $c->stash({
        template       => 'message.xml',
        target_folders => [ sort {($a->{name} or '') cmp ($b->{name} or '')} values %{ clone($c->stash->{folders_hash}) } ],
        uri_reply      => $c->uri_for("/mailbox/$mailbox/$uid/reply/sender"),
        uri_reply_all  => $c->uri_for("/mailbox/$mailbox/$uid/reply/all"),
        uri_forward    => $c->uri_for("/mailbox/$mailbox/$uid/forward"),
        uri_move       => $c->uri_for("/mailbox/$mailbox/$uid/move"),
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

=head2 delete

Delete a message

=cut

sub delete : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    
    $c->stash->{message}->delete();
    
    $c->res->body('message deleted');
}

=head2 move

Move a message to a different folder

=cut

sub move : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $target_folder = $c->req->param('target_folder') or die "no folder to move message to";
    my $model = $c->model();

    #TODO fixme
    #$model->move_message($c, {uid => $c->stash->{message}, mailbox => $c->stash->{folder}, target_mailbox => $target_folder});

    $c->res->body('message moved');
}

=head2 compose

Compose a new message for sending

=cut

sub compose : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    my $folders = clone($c->stash->{folders_hash});
    delete $_->{selected} foreach values %$folders; # clean any selectedness

    my $sent = first { $_ =~ /\bsent\b/i } keys %$folders; # try to find a folder called "Sent"
    $folders->{$sent}{selected} = 'selected' if $sent;

    $c->stash->{message} ||= {};
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
        from    => $message->to, #this is stupd... we should not use the to address here...
        subject => 'Re: ' . $message->subject,
        body    => $body,
    };

    if ($who eq 'sender') {
        my $recipient = ($message->reply_to or $message->from);
        $new_message->{to} = $recipient->[0]->address;
    } elsif ($who eq 'all') {
        my @recipients;
        foreach( ( ( $message->reply_to or $message->from ), $message->cc ) ) {
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

    my $mail = MIME::Lite->new(
        From    => $c->req->param('from'),
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

    if (my $sent_folder = $c->req->param('sent_folder')) {
        my $msg_text = $mail->as_string;
        $c->model()->append_message($c, {mailbox => $sent_folder, message_text => $msg_text});
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
