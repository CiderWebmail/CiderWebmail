# ------------------------------------------------------------------
# Petal::Hash::String - Interpolates variables with other strings
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# This module is redistributed under the same license as Perl
# itself.
# ------------------------------------------------------------------
package Petal::Hash::String;
use strict;
use warnings;
use Carp;


our $VARIABLE_RE_SIMPLE   = qq |\\\$[A-Za-z_][A-Za-z0-9_\\.:\/]+|;
our $VARIABLE_RE_BRACKETS = qq |\\\$(?<!\\\\)\\{.*?(?<!\\\\)\\}|;
our $TOKEN_RE             = "(?:$VARIABLE_RE_SIMPLE|$VARIABLE_RE_BRACKETS)";


sub process
{
    my $self = shift;
    my $hash = shift;
    my $argument = shift;

    $Petal::TranslationService && do {
        $argument = eval { $Petal::TranslationService->maketext ($argument) } || $argument;
        $@ and warn $@;
    };
    
    my $tokens = $self->_tokenize (\$argument);
    my @res = map {
	($_ =~ /$TOKEN_RE/gsm) ?
	    do {
		s/^\$//;
		s/^\{//;
		s/\}$//;
		$hash->fetch ($_);
	    } :
	    do {
		s/\\(.)/$1/gsm;
		$_;
	    };
    } @{$tokens};
    
    return join '', map { defined $_ ? $_ : () } @res;
}


# $class->_tokenize ($data_ref);
# ------------------------------
#   Returns the data to process as a list of tokens:
#   ( 'some text', '<% a_tag %>', 'some more text', '<% end-a_tag %>' etc.
sub _tokenize
{
    my $self = shift;
    my $data_ref = shift;
    
    my @tokens = $$data_ref =~ /($TOKEN_RE)/gs;
    my @split  = split /$TOKEN_RE/s, $$data_ref;
    my $tokens = [];
    while (@split)
    {
        push @{$tokens}, shift (@split);
        push @{$tokens}, shift (@tokens) if (@tokens);
    }
    push @{$tokens}, (@tokens);
    return $tokens;
}


1;


__END__
