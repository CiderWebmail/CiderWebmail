package Petal::Utils::Equal;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'equal';
use constant aliases => qw( eq );

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.3 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'equal' expects 2 variables (got nothing)!" );

    my @args = $class->split_first_arg( $args );
    my $arg1 = $args[0] || confess( "1st arg to 'equal' should be a variable (got nothing)!" );
    my $arg2 = $args[1] || confess( "2nd arg to 'equal' should be a variable (got nothing)!" );

    my $h1 = $hash->fetch($arg1);
    my $h2 = $hash->fetch($arg2);

    return $h1 == $h2 ? 1 : 0 if ($h1 =~ /\A\d+\z/ and $h2 =~ /\A\d+\z/);
    return $h1 eq $h2 ? 1 : 0;
}

1;
