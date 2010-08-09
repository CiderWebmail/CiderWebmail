package Petal::Utils::Like;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'like';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.3 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'like' expects a variable and a regex (got nothing)!" );

    my @args = $class->split_first_arg( $args );
    $args    = $args[0] || confess( "1st arg to 'like' should be a variable (got nothing)!" );
    my $re   = $args[1] || confess( "2nd arg to 'like' should be a regex (got nothing)!" );

    my $result = $hash->fetch( $args );

    return $result =~ /$re/ ? 1 : 0;
}

1;
