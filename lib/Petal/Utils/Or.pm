package Petal::Utils::Or;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'or';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'or' expects 2 variables (got nothing)!" );

    my @args = $class->split_first_arg( $args );
    my $arg1 = $args[0] || confess( "1st arg to 'or' should be a variable (got nothing)!" );
    my $arg2 = $args[1] || confess( "2nd arg to 'or' should be a variable (got nothing)!" );

    my $h1 = $hash->fetch($arg1);
    my $h2 = $hash->fetch($arg2);

    return ($h1 || $h2) ? 1 : 0;
}

1;

__END__

# Perform an OR comparison
