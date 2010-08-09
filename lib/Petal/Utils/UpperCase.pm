package Petal::Utils::UpperCase;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'uppercase';
use constant aliases => qw( uc );

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'uppercase' expects a variable (got nothing)!" );
    my $result = $hash->fetch($args);
    return uc($result);
}

1;

