package CiderWebmail::Controller::Message;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Message;
use MIME::Lite;
use MIME::Words qw/encode_mimeword/;

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
    $c->stash->{message} = $uid;
}


=head2 view 

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $uid = $c->stash->{message};
    my $model = $c->model();

    die("mailbox not set") unless defined($mailbox);
    die("uid not set") unless defined($uid);

    my $message = CiderWebmail::Message->new($c, { mailbox => $mailbox, uid => $uid } );
    $message->load_body();

    $c->stash({
        template => 'message.xml',
        message => $message,
        uri_reply => $c->uri_for("/mailbox/$mailbox/$uid/reply"),
    });
}

=head2 attachment

=cut

sub attachment : Chained('setup') Args(1) {
    my ( $self, $c, $id ) = @_;

    my $mailbox = $c->stash->{folder};
    my $uid = $c->stash->{message};
    my $message = CiderWebmail::Message->new($c, { mailbox => $mailbox, uid => $uid } );

    my $attachment = ( $message->attachments )[$id];
    $c->res->content_type($attachment->{type});
    $c->res->header('content-disposition' => ($c->res->headers->content_is_html ? 'inline' : 'attachment') . "; filename=$attachment->{name}");
    $c->res->body($attachment->{data});
}

=head2 delete

Delete a message

=cut

sub delete : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $uid = $c->stash->{message};
    my $model = $c->model();

    die("mailbox not set") unless defined($mailbox);
    die("uid not set") unless defined($uid);

    my $message = CiderWebmail::Message->new($c, { mailbox => $mailbox, uid => $uid } );

    $message->delete();
    
    $c->res->redirect($c->uri_for('/mailbox/' . $c->stash->{folder}));
}


=head2 compose

Compose a new message for sending

=cut

sub compose : Chained('/mailbox/setup') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{message} ||= {};
    $c->stash({
        uri_send => $c->uri_for('/mailbox/' . $c->stash->{folder} . '/send'),
        template => 'compose.xml',
    });
}

=head2 reply

Reply to a message suggesting receiver, subject and message text

=cut

sub reply : Chained('setup') Args(0) {
    my ( $self, $c ) = @_;
    my $mailbox = $c->stash->{folder};
    my $uid = $c->stash->{message};
    my $message = CiderWebmail::Message->new($c, { mailbox => $mailbox, uid => $uid } );
    my $body = $message->body;
    $body =~ s/[\s\r\n]+\z//s;
    $body =~ s/^/> /gm;
    $body .= "\n\n";

    $c->stash({
        message => {
            to => ($message->get_header('reply-to') or $message->from),
            subject => 'Re: ' . $message->subject,
            body => $body,
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

    $mail->send;

    $c->res->redirect($c->uri_for('/mailbox/' . $c->stash->{folder}));
}

=head1 AUTHOR

,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
