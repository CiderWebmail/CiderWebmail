package Petal::TranslationService::MOFile;
use Locale::Maketext::Gettext;
use Encode;
use strict;
use warnings;


sub new
{
    my $class = shift;
    my $file  = shift || do {
        warn "No file specified for " . __PACKAGE__ . "::new (\$file)";
        return bless {}, $class;
    };

    -e $file or do { 
        warn "$file does not seem to exist";
        return bless {}, $class;
    };

    -f $file or do {
        warn "$file does not seem to be a file";
        return bless {}, $class;
    };

    my $self = bless { file => $file }, $class;
    $self->{lexicon} = { read_mo ($file) };

    ($self->{encoding}) = $self->{lexicon}{""} =~ /^Content-Type: text\/plain; charset=(.*)$/im;
    return $self;
}


sub maketext
{
    my $self = shift;
    my $id   = shift || return;
    $self->{lexicon} || return;
    my $res  = $self->{lexicon}->{$id};

    return undef unless defined $res;

    return decode($self->{encoding}, $res);
}


1;


__END__
