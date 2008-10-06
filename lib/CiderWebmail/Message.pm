package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use DateTime;
use DateTime::Format::Mail;

use Cache::FastMmap;

use Text::Iconv;

sub new {
    my ($class, $c, $o) = @_;

    die("mailbox not set") unless( defined($o->{'mailbox'}) );
    die("uid not set") unless( defined($o->{'uid'}) );

    my $message = {
        c => $c,
        mailbox => $o->{'mailbox'},
        uid => $o->{'uid'},
    };

    bless $message, $class;
}

sub uid {
    my ($self) = @_;

    return $self->{'uid'};
}

sub mailbox {
    my ($self) = @_;

    return $self->{'mailbox'};
}

#select the mailbox of the message
sub switch_mailbox {
    my ($self) = @_;

    $self->{c}->model->select( $self->{c}, { mailbox => $self->mailbox } );
    return;
}

sub subject {
    my ($self) = @_;
    
    return $self->{c}->model->get_header($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, header => "Subject", decode => 1 });
}

sub from {
    my ($self) = @_;

    return $self->{c}->model->get_header($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, header => "From", decode => 1 });
}

sub uri_view {
    my ($self) = @_;

    return $self->{c}->uri_for("/message/view/$self->{mailbox}/$self->{uid}");
}

#returns a datetime object
sub date {
    my ($self) = @_;

    return $self->{c}->model->date($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub body {
    my ($self) = @_;

    return $self->{c}->model->body($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

1;
