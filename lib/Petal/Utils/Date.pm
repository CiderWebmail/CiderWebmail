package Petal::Utils::Date;

use strict;
use warnings::register;

use Carp;
use Date::Format;

use base qw( Petal::Utils::Base );

use constant name    => 'date';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $self = shift;
    my $hash = shift;
    my $args = shift || confess( "'date' expects a variable (got nothing)" );
    my $result = $hash->fetch( $args );
    return unless length($result); # do nothing if $args evaluates to nothing
    return time2str('%b %e %Y %T', $result);
}

1;
