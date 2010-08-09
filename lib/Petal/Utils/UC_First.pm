package Petal::Utils::UC_First;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'uc_first';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'uc_first' expects a variable (got nothing)!" );
    my $result = $hash->fetch($args);
    return "\u$result";
}

1;

__END__

# Uppercase the first letter of the string
