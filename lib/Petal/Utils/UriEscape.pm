package Petal::Utils::UriEscape;

use strict;
use warnings::register;

use Carp;
use URI::Escape qw( &uri_escape );

use base qw( Petal::Utils::Base );

use constant name    => 'uri_escape';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.1 $ '))[2];

sub process {
    my $self = shift;
    my $hash = shift;
    my $args = shift || confess( "'uri_escape' expects a variable (got nothing)" );
    my $result = $hash->fetch( $args );
    return unless length( $result ); # do nothing if $args evaluates to nothing
    return uri_escape( $result );
}

1;
