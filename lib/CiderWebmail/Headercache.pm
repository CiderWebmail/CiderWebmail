package CiderWebmail::Headercache;

use Moose;

use Cache::FastMmap;
use File::Spec;

has c     => (is => 'ro', isa => 'Object');

=head2 get()

fetch a header from the per-request cache
return undef if the header was not found in the cache

=cut

sub get {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};
    
    die "hc get w/o mailbox" unless defined $o->{mailbox};

    if (exists $self->c->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{$o->{header}}) {
        return $self->c->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{$o->{header}};
    }

    return;
}

=head2 set()

insert a header into the per-request cache

=cut

sub set {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};
    die unless defined $o->{mailbox};

    $self->c->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{lc($o->{header})} = $o->{data};

    return;
}

1;
