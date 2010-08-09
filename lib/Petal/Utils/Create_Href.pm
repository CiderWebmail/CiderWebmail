package Petal::Utils::Create_Href;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'create_href';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'create_href' expects 1 or 2 variables (got nothing)!" );

    my @args = $class->split_args( $args );
    my $key = $args[0] || confess( "1st arg to 'limit' should be a variable (got nothing)!" );
    my $protocol = $args[1] || 'http';

    my $href = $hash->fetch($key);
    unless ($href =~ /^$protocol:/) {
      $protocol = "$protocol://";
      $protocol .= '/' if $protocol =~ /file/i;
      $href = $protocol . $href;
    }
    return $href;

}

1;

__END__

Description: Creates an absolute uri from a url with the given protocol (e.g.,
http, ftp).  If the url does not have the protocol included, it will be
appended. If no protocol is given, 'http' will be used.

Basic Usage:
  create_href:<url> <protocol>
    url - a string
    protocol - http, ftp, etc.

Example:
  <a petal:attr="href create_href:$url">HTTP Link</a>
  <a petal:attr="href create_href:$url ftp">FTP Link</a>
