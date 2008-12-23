package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use DateTime;
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
        uid     => $o->{uid},
        from    => $o->{from},
        to      => $o->{to},
        subject => $o->{subject},
        date    => $o->{date}, #datetime object
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

sub subject {
    my ($self) = @_;
   
    unless ( $self->{subject} ) {
        $self->{subject} = $self->{c}->model->get_header($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, header => "Subject", decode => 1, cache => 1 });
    }

    return $self->{subject};
}

sub from {
    my ($self) = @_;

    unless( $self->{from} ) {
        $self->{from} = $self->{c}->model->get_header($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, header => "From", decode => 1, cache => 1 });
    }

    return $self->{from};
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

    unless( $self->{date} ) {
        $self->{date} = $self->{c}->model->date($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
    }

    return $self->{date};
}

sub load_body {
    my ($self) = @_;

    ($self->{body}, $self->{attachments}) = $self->{c}->model->body($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub body {
    my ($self) = @_;

    $self->load_body unless $self->{body};

    return $self->{body};
}

sub delete {
    my ($self) = @_;

    $self->{c}->model->delete_messages($self->{c}, { uids => [ $self->uid ], mailbox => $self->mailbox } );
}
1;
