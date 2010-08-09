package Petal::TranslationService::Noop;
use warnings;
use strict;

sub new
{
    my $class = shift;
    return bless {}, $class;
}

sub maketext
{
    my $self = shift;
    return join '', @_;
}

1;


__END__ 
