package Petal::Utils::Limit;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'limit';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'limit' expects 2 variables (got nothing)!" );

    my @args = $class->split_args( $args );
    my $key = $args[0] || confess( "1st arg to 'limit' should be an array (got nothing)!" );
    my $count = $args[1] || confess( "2nd arg to 'limit' should be a variable (got nothing)!" );

    my $arrayref = $hash->fetch($key);
    $count--;
    # trim $count to max size of array
    $count = $#$arrayref if $#$arrayref < $count;
    return [] if $count < 0;
    return [@{$arrayref}[0 .. $count]];
}

1;

__END__

Description: Limit elements returned from an array

Basic Usage:
  limit:<list> <count>
    list - a list
    count - an integer value, if greater than the total items in the list,
      return complete list

Example:
    <div class="content" tal:repeat="fact limit:facts 2">
      <p tal:content="fact/fld_fact">Fact</p>
    </div>
