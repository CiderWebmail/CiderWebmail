package CiderWebmail::IMAPClient;

use warnings;
use strict;

sub new {
    my ($class, $c, $o) = @_;

    #TODO move imap code here?
    my $imap = {
        imap => undef,
    };

    bless $imap, $class;
}

sub _imap {
    my ($self) = @_;

    return $self->{imap};
}

1;
