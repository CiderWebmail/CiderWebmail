package Petal::Utils::Limitr;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'limitr';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'limitr' expects 2 variables (got nothing)!" );

    my @args = $class->split_args( $args );
    my $key = $args[0] || confess( "1st arg to 'limit' should be an array (got nothing)!" );
    my $count = $args[1] || confess( "2nd arg to 'limit' should be a variable (got nothing)!" );

    my $arrayref = $hash->fetch($key);
    # Shuffle full array
    fisher_yates_shuffle($arrayref);
    $count--;
    # trim $count to max size of array
    $count = $#$arrayref if $#$arrayref < $count;
    return [] if $count < 0;
    return [@{$arrayref}[0 .. $count]];

}


# Generate a random permutation of @array in place
# Usage: fisher_yates_shuffle( \@array ) :
sub fisher_yates_shuffle {
  my $array = shift;
  return unless $#$array >= 0;
  my $i;
  for ($i = @$array; --$i; ) {
    my $j = int rand ($i+1);
    next if $i == $j;
    @$array[$i,$j] = @$array[$j,$i];
  }
}


1;

__END__

Description: Limit elements returned from a randomized array

Basic Usage:
  limitr:<list> <count>
    list - a list
    count - an integer value, if greater than the total items in the list,
      return complete list

Example:
    <div class="content" tal:repeat="fact limitr:facts 2">
      <p tal:content="fact/fld_fact">Fact</p>
    </div>
