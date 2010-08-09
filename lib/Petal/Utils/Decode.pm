package Petal::Utils::Decode;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'decode';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.3 $ '))[2];

sub process {
  my $class = shift;
  my $hash  = shift;
  my $args  = shift || confess( "'decode' expects at least 1 variable (got nothing)!" );

  my @tokens = $class->split_args( $args );

  my $tvar = $class->fetch_arg($hash, shift @tokens);
  use Data::Dumper;
  while(@tokens) {
    my $a = $class->fetch_arg($hash, shift @tokens);
    my $b = $class->fetch_arg($hash, shift @tokens);
    return $a unless defined($b);
    return $b if ($tvar =~ /$a/);
  }
}



1;

__END__

Description: The decode function has the functionality of an IF-THEN-ELSE
statement. A case-sensitive regex comparison is performed.


Basic Usage:
  decode: expression search result [search result]... [default]
    expression is the value to compare.
    search is the value that is compared against expression.
    result is the value returned, if expression is equal to search.
    default is optional.  If no matches are found, the decode will return
      default.  If default is omitted, then the decode statement will return
      null (if no matches are found). 

  All text strings must be enclosed in single quotes.


Example:
  If $str = dog,
  <p petal:content="decode:$str 'dog'">string</p>  # true
  <p petal:content="decode:$str 'dog' 100">string</p>  # false
  <p petal:content="decode:$str 'dog' 'Barker'">string</p>  # false

See also:
  http://www.techonthenet.com/oracle/functions/decode.htm
  Test template t/data/25__decode.html for more examples of use.
