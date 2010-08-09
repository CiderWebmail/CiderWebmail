package Petal::TranslationService::h4x0r;
use Petal::Hash::String;
use Lingua::31337;
use warnings;
use strict;


sub new
{
    my $class = shift;
    return bless { @_ }, $class;
}


sub maketext
{
    my $self   = shift;
    my $string = shift;
    my @tokens = @{Petal::Hash::String->_tokenize (\$string)};
    my @res = map { ($_ =~ /$Petal::Hash::String::TOKEN_RE/gsm) ? $_ : Lingua::31337::text231337 ($_) } @tokens;
    return join '', @res;
}


1;


__END__
