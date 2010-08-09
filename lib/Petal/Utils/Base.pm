package Petal::Utils::Base;

#rename: package Petal::Plugin; ?

use strict;
use warnings::register;

use Carp;

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.5 $ '))[2];

## Define the enclosed packages inside the Petal Modifiers hash
sub install {
    my $class = shift;

    foreach my $name ($class->name, $class->aliases) {
	$Petal::Hash::MODIFIERS->{"$name:"} = $class;
    }

    return $class;
}

sub process {
    my $class = shift;
    confess( "$class does not override process()" );
}

sub name {
    my $class = shift;
    confess( "$class does not override name()" );
}

sub aliases {
    my $class = shift;
    confess( "$class does not override aliases()" );
}

sub split_first_arg {
    my $class = shift;
    my $args  = shift;
    # don't use split(/\s/,...) as we might kill an expression that way
    return ($args =~ /\A(.+?)\s+(.*)\z/);
}

# Return a list of all arguments as an array - does not perform expansion on
# embedded modifiers
sub split_args {
  my $class = shift;
  my ($args) = @_;
  # W. Smith's regex
  return ($args =~ /('[^']+'|\S+)/g);
}

# Returns an argument from the data hash as a string/object or as a plaintext
# if arg is surrounded by single quotes or a number (decimal points OK)
# Arguments:
#   $hash - reference to the Petal data hash
#   $arg - the argument
sub fetch_arg {
  my $class = shift;
  my ($hash, $arg) = @_;

  return undef unless defined($arg);
  if($arg =~ /\'/) {
    $arg =~ s/\'//g;
    return $arg;
  }
  elsif($arg =~ /^[0-9.]+$/) {
    return $arg;
  }
  else {
    #warn "Returning hash key for $arg";
    return $hash->fetch($arg);
  }
}




1;

