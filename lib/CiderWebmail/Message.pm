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

sub get_header {
    my ($self, $header) = @_;
    unless ($self->{$header}) {
        $self->{$header} = $self->{c}->model->get_header($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, header => $header, decode => 1, cache => 1 });
    }
    return $self->{$header};
}

sub subject {
    my ($self) = @_;

    return ($self->get_header('subject') or 'No Subject');
}

sub from {
    my ($self) = @_;

    return ($self->get_header('from') or 'Unknown');
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

    foreach (@{ $self->{attachments} }) {
        $_->{uri_view} = $self->{c}->uri_for('/mailbox/' . $self->mailbox . '/' . $self->uid . "/attachment/$_->{id}");
    }
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

    $self->{c}->model->body_as_string($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

1;
