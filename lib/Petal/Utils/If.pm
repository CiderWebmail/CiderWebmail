package Petal::Utils::If;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'if';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'if' expects args of the form 'if: ... then: ... [else: ...]' (got nothing)!" );

    my @args = $args =~ /\A(.+?)\sthen:\s+(.+?)(?:\s+else:\s+(.+?))?\z/;
    confess( "'if' expects arguments of the form: 'if: ... then: ... [else: ...]', not 'if: $args'!" ) unless @args;
    $args[0] || confess( "1st arg to 'if' should be an expression (got nothing)!" );
    $args[1] || confess( "2nd arg to 'if' (after then:) should be an expression (got nothing)!" );

    return $hash->fetch($args[1]) if $hash->fetch($args[0]);
    return $hash->fetch($args[2]) if $args[2];
    return '';
}

1;
