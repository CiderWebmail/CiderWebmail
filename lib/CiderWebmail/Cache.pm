package CiderWebmail::Cache;

use Moose;

use File::Spec;
use Carp qw/ croak /;

has cache => (is => 'rw', isa => 'HashRef', default => sub { {}; } );


=head2 get()

fetch a key from the per-request cache
return undef if the key was not found in the cache

=cut

sub get {
    my ($self, $o) = @_;

    croak unless defined $o->{uid};
    croak unless defined $o->{key};
    
    croak("hc get w/o mailbox") unless defined $o->{mailbox};

    if (exists $self->cache->{$o->{mailbox}}->{$o->{uid}}->{$o->{key}}) {
        return $self->cache->{$o->{mailbox}}->{$o->{uid}}->{$o->{key}};
    }

    return;
}

=head2 set()

insert a key into the per-request cache

=cut

sub set {
    my ($self, $o) = @_;

    croak unless defined $o->{uid};
    croak unless defined $o->{key};
    croak unless defined $o->{mailbox};

    $self->cache->{$o->{mailbox}}->{$o->{uid}}->{lc($o->{key})} = $o->{data};

    return;
}

1;
