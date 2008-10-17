package CiderWebmail::Mailbox;

use warnings;
use strict;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};

    my $mailbox = {
        mailbox => $o->{mailbox},
    };

    bless $mailbox, $class;
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

1;
