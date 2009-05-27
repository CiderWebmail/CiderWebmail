use warnings;
use strict;

use Cache::FastMmap;

package CiderWebmail::Headercache;

my $headercache = Cache::FastMmap->new( share_file => '/tmp/headercache', cache_size => '64m' );

sub new {
    my ($class, $c, $o) = @_;

    my $cache = {
        c => $c,
        cache => $headercache,
    };

    bless $cache, $class;
}

=head2 get()

fetch a header from the request or the on-disk cache
return undef if the header was not found in the cache

=cut

sub get {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};
    
    die "hc get w/o mailbox" unless defined $o->{mailbox};

    if (exists $self->{c}->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{$o->{header}}) {
        return $self->{c}->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{$o->{header}};
    }

    if (defined($self->{cache}->get( join('_', $o->{uid}, lc($o->{header}), $self->{c}->user->id) ))) {
        return $self->{cache}->get( join('_', $o->{uid}, lc($o->{header}), $self->{c}->user->id) );
    }

    return undef;
}

=head2 set()

insert a header into the request and (if appropriate) the on-disk cache

=cut

sub set {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};
    die unless defined $o->{mailbox};

    my %ondisk = (Date => 1, From => 1, To => 1, Subject => 1);

    $self->{c}->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{lc($o->{header})} = $o->{data};
  
    if (exists($ondisk{$o->{header}})) {
        $self->{cache}->set( join('_', $o->{uid}, lc($o->{header}), $self->{c}->user->id), $o->{data} ) || die;
    }
}

1;
