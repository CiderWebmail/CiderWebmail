package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use DateTime;
use Mail::Address;
use DateTime::Format::Mail;

use Text::Iconv;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    #TODO add headers passed here to the header cache
    my $message = {
        c => $c,
        mailbox => $o->{mailbox},
        uid     => $o->{uid}
    };

    bless $message, $class;
}

sub uid {
    my ($self) = @_;

    return $self->{uid};
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

sub get_header {
    my ($self, $header) = @_;

    my $headers = $self->{c}->model->get_headers($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, headers => [$header]});
    
    return $headers;
}

#TODO formatting
sub header_formatted {
    my ($self) = @_;

    return $self->{c}->model->get_headers_string($self->{c}, { uid => $self->{uid}, mailbox => $self->{mailbox} });
}


sub subject {
    my ($self) = @_;

    return ($self->get_header('subject') or 'No Subject');
}

sub from {
    my ($self) = @_;

    my @from = Mail::Address->parse($self->get_header('from'));
    return \@from;
}

sub to {
    my ($self) = @_;

    my @to = Mail::Address->parse($self->get_header('to'));
    return \@to;
}

sub cc {
    my ($self) = @_;

    my @cc = Mail::Address->parse($self->get_header('cc'));
    return \@cc;
}


sub get_headers {
    my ($self) = @_;
    
    return {
        subject     => $self->subject(),
        from        => $self->from,
        date        => $self->date->strftime("%F %T"),
        uid         => $self->uid,
    };
}


#returns a datetime object
sub date {
    my ($self) = @_;

    return $self->{c}->model->date($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub load_body {
    my ($self) = @_;

    ($self->{body}, $self->{attachments}) = $self->{c}->model->body($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub body {
    my ($self) = @_;

    $self->load_body unless exists $self->{body};

    return $self->{body};
}

sub attachments {
    my ($self) = @_;

    $self->load_body unless exists $self->{attachments};

    return wantarray ? @{ $self->{attachments} } : $self->{attachments};
}

sub delete {
    my ($self) = @_;

    $self->{c}->model->delete_messages($self->{c}, { uids => [ $self->uid ], mailbox => $self->mailbox } );
}

sub as_string {
    my ($self) = @_;

    $self->{c}->model->message_as_string($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

1;
