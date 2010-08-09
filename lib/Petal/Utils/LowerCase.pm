package Petal::Utils::LowerCase;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'lowercase';
use constant aliases => qw( lc );

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'lowercase' expects a variable (got nothing)!" );
    my $result = $hash->fetch($args);
    return lc($result);
}

1;
