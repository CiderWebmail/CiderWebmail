use warnings;
use strict;

use Cache::FastMmap;

package CiderWebmail::Headercache;

sub new {
    my ($class, $c, $o) = @_;

    my $cache = {
        c => $c,
        cache => Cache::FastMmap->new( share_file => '/tmp/headercache', cache_size => '64m' ),
    };

    bless $cache, $class;
}

sub get {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};

    return $self->{cache}->get( join('_', $o->{uid}, $o->{header}, $self->{c}->user->id) );
}

sub set {
    my ($self, $o) = @_;

    die unless defined $o->{uid};
    die unless defined $o->{header};

    $self->{cache}->set( join('_', $o->{uid}, $o->{header}, $self->{c}->user->id), $o->{data} ) || die;
}

1;
