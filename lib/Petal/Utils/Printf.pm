package Petal::Utils::Printf;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'printf';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.3 $ '))[2];

sub process {
  my $class = shift;
  my $hash  = shift;
  my $args  = shift || confess( "'printf' expects at least 2 arguments (got nothing)!" );

  my @tokens = $class->split_args( $args );
  my $format = shift @tokens;
  $format =~ s/\'//g;
  my @printf_args = ();
  foreach my $arg (@tokens) {
    push @printf_args, $class->fetch_arg($hash, $arg);
  }
  return sprintf($format, @printf_args);
}



1;

__END__

Description: The printf modifier acts exactly like Perl's sprintf function to
print formatted strings.


Basic Usage:
  printf: format list
    format is the string you wish to be interpolated by printf
    list is a list of values to insert

Example:
  <p petal:content="printf:'%s' 'Astro'">Astro</p>  # true
  <p petal:content="printf:'%02d' '2'">02</p>  # false

See also:
  Test template t/data/26__printf.html for more examples of use.
