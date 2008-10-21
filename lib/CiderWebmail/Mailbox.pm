package CiderWebmail::Mailbox;

use warnings;
use strict;

use CiderWebmail::Message;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};

    my $mailbox = {
        mailbox => $o->{mailbox},
        c => $c,
    };

    bless $mailbox, $class;
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

sub list_messages {
    my ($self, $c, $o) = @_;

    my $messages_header_hash = $c->model->fetch_headers_hash($c, { mailbox => $self->{mailbox} });
    my @messages = ();

    foreach ( @$messages_header_hash ) {
        my $message = $_;
        push(@messages, CiderWebmail::Message->new($self->{c},
            {
                mailbox => $message->{mailbox},
                uid     => $message->{uid},
                from    => $message->{from},
                to      => $message->{to},
                subject => $message->{subject},
                date    => $message->{date},
            }));
    }

    return \@messages;
}

sub list_messages_hash {
    my ($self, $c, $o) = @_;
    
    return $c->model->fetch_headers_hash($c, { mailbox => $self->{mailbox} });
}

1;
