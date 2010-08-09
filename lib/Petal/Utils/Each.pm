package Petal::Utils::Each;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'each';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'each' expects a hash ref (got nothing)" );

    my $result = $hash->fetch( $args );

    confess( "1st arg to 'each' is not a hash ($args = $result)!" )
      unless ref($result) eq 'HASH';

    return [ map { { key => $_, val => $result->{$_} } } keys %$result ];
}


1;

__END__

# Return a list of key/value pairs for a hashref
