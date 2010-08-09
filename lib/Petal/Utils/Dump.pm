package Petal::Utils::Dump;

use strict;
use warnings::register;

use Carp;
use Data::Dumper;

use base qw( Petal::Utils::Base );

use constant name    => 'dump';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.3 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'dump' expects a variable (got nothing)" );
    my $result = $hash->fetch( $args );
    return Dumper( $result );
}

1;
