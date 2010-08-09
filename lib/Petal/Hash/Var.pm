# ------------------------------------------------------------------
# Petal::Hash::Var - Evaluates an expression and returns the result.
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# This module is redistributed under the same license as Perl
# itself.
# ------------------------------------------------------------------
package Petal::Hash::Var;

use strict;
use warnings;

use Carp;
use Scalar::Util qw( blessed reftype );


our $STRING_RE_DOUBLE  = qr/(?<!\\)\".*?(?<!\\)\"/;
our $STRING_RE_SINGLE  = qr/(?<!\\)\'.*?(?<!\\)\'/;
our $STRING_RE         = qr/(?:$STRING_RE_SINGLE|$STRING_RE_DOUBLE)/;
our $VARIABLE_RE       = qr/(?:--)?[A-Za-z\_][^ \t]*/;
our $PARAM_PREFIX_RE   = qr/^--/;
our $ESCAPED_CHAR_RE   = qr/(?sm:\\(.))/;
our $BEGIN_QUOTE_RE    = qr/^\"|\'/;
our $END_QUOTE_RE      = qr/\"|\'$/;
our $TOKEN_RE          = qr/(?:$STRING_RE|$VARIABLE_RE)/;
our $PATH_SEPARATOR_RE = qr/(?:\/|\.)/;
our $INTEGER_KEY_RE    = qr/^\d+$/;


sub process
{
    my $class    = shift;
    my $hash     = shift;
    my $argument = shift;
    
    my @tokens = $argument =~ /($TOKEN_RE)/gsm;
    my $path   = shift (@tokens) or confess "bad syntax for $class: $argument (\$path)";
    my @path   = split( /$PATH_SEPARATOR_RE/, $path );
    my @args   = @tokens;

    # replace variable names by their value
    for (my $i=0; $i < @args; $i++)
    {
	my $arg = $args[$i];
	if ($arg =~ /^$VARIABLE_RE$/)
	{
	    $arg =~ s/$ESCAPED_CHAR_RE/$1/gsm;
	    if ($arg =~ $PARAM_PREFIX_RE)
	    {
		$arg =~ s/$PARAM_PREFIX_RE//;
		$args[$i] = $arg;
	    }
	    else
	    {
		$args[$i] = $hash->fetch ($arg);
	    }
	}
	else
	{
	    $arg =~ s/$BEGIN_QUOTE_RE//;
	    $arg =~ s/$END_QUOTE_RE//;
	    $arg =~ s/$ESCAPED_CHAR_RE/$1/gsm;
	    $args[$i] = $arg;
	}
    }
    
    my $current = $hash;
    my $current_path = '';
    while (@path)
    {
	my $next = shift (@path);
	$next = ($next =~ /:/) ? $hash->fetch ($next) : $next;
	
	my $has_path_tokens = scalar @path;
	my $has_args        = scalar @args;
	
	if (blessed $current)
	{
	  ACCESS_OBJECT:
	    goto ACCESS_HASH if ($current->isa('Petal::Hash'));

	    if ($current->can ($next) or $current->can ('AUTOLOAD'))
	    {
		if ($has_path_tokens) { $current = $current->$next ()      }
		else                  { $current = $current->$next (@args) }
	    }
	    else
	    {
		goto ACCESS_HASH  if ((reftype($current) or '') eq 'HASH');
		goto ACCESS_ARRAY if ((reftype($current) or '') eq 'ARRAY');
		confess "Cannot invoke '$next' on '" . ref($current) .
		  "' object at '$current_path' - no such method (near $argument)";
	    }
	}
	elsif (ref($current) eq 'HASH')
	{
	  ACCESS_HASH:
          unless (ref($current->{$next}) eq 'CODE')
          {
	    confess "Cannot access hash at '$current_path' with parameters (near $argument)"
	        if ($has_args and not $has_path_tokens);
          }
	    $current = $current->{$next};
	}
	elsif (ref($current) eq 'ARRAY')
	{
	  ACCESS_ARRAY:
	    # it might be an array, then the key has to be numerical...
	    confess "Cannot access array at '$current_path' with non-integer index '$next' (near $argument)"
	        unless ($next =~ /$INTEGER_KEY_RE/);

	    confess "Cannot access array at '$current_path' with parameters (near $argument)"
	        if ($has_args and not $has_path_tokens);

	    $current = $current->[$next];
	}
	else
	{
	    # ... or we cannot find the next value
	    if ($Petal::ERROR_ON_UNDEF_VAR)
	    {
		# let's croak and return
		my $warnstr = "Cannot find value for '$next' at '$current_path': $next cannot be retrieved\n";
		$warnstr   .= "(current value was ";
		$warnstr   .= (defined $current) ? "'$current'" : 'undef';
		$warnstr   .= ", near $argument)";
		confess $warnstr;
	    }
	    return '';
	}

	$current = (ref($current) eq 'CODE') ? $current->(@args) : $current;
	$current_path .= "/$next";
    }
    
    # return '' unless (defined $current);
    # $current = "$current" if (defined $current);
    return $$current if ref($current) eq 'SCALAR';
    return $current;
}


1;










