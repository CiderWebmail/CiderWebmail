package Petal::Utils::Substr;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'substr';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'create_href' expects 1 or 2 variables (got nothing)!" );

    my @args = $class->split_args( $args );
    my $text_key = $args[0] || confess( "1st arg to 'limit' should be a variable (got nothing)!" );
    my $text = $hash->fetch($text_key);
    my $start = $args[1] || 0;
    my $len = $args[2] || length($text);
    my $ellipsis = $args[3] || 0;

    my $new_text = substr($text, $start, $len);
    if ( $ellipsis && (length($new_text) >= ($len - $start)) ) {
      $new_text .= "...";
    }
    return $new_text;

}

1;

__END__

Description: Extract a substring.

Basic Usage:
  substr: <string> <offset> <length> <ellipsis>
    string - a string
    offset - offset from beginning of string (optional)
    length - length of string (optional)
    ellipsis - set to true to add an ellipsis (...) if original string is
      truncated (optional)

Example:
  <span petal:content="substr:$str">string</span>       # does nothing
  <span petal:content="substr:$str 2">string</span>     # cuts the first two chars
  <span petal:content="substr:$str 2 5">string</span>   # extracts chars 2-7
  <span petal:content="substr:$str 2 5 1">string with ellipsis</span>  # same as above and adds an ellipsis

See also:
  `perldoc -f substr`

