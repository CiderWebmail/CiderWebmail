package Petal::TranslationService::Gettext;
use Petal::TranslationService::MOFile;
use warnings;
use strict;

sub new
{
    my $class = shift;
    return bless {
        # defaults...
        locale_dir  => '/usr/share/locale',
        target_lang => 'en',

        # optional overriding args
        @_,
    }, $class;
}


sub maketext
{
    my $self = shift;
    my $tsrv = $self->mo_file_translation_service();
    ref $tsrv and return $tsrv->maketext (@_);
    return;
}


sub target_lang
{
    my $self = shift;
    $self->{target_lang} =~ s/-/_/;
    return $self->{target_lang};
}


sub mo_file_translation_service
{
    my $self   = shift;
    my $domain = $Petal::I18N::Domain || 'default';
    $self->{mo_file_tranlation_services} ||= {};
    $self->{mo_file_tranlation_services}->{$domain} ||= $self->_mo_file_translation_service();
    return $self->{mo_file_tranlation_services}->{$domain};
}


sub _mo_file_translation_service
{
    my $self   = shift;
    my $target_lang = $self->target_lang() || die 'target_lang() returned undef';
    my $domain = $Petal::I18N::Domain || 'default';
    my $res    = undef;

    $res = $self->_instanciate_mo_file_tranlation_service_if_file_exists ($target_lang);
    $res && return $res;

    $target_lang =~ s/_.*$//;

    $res = $self->_instanciate_mo_file_tranlation_service_if_file_exists ($target_lang);
    $res && return $res;

    return '__none__';
}


sub _instanciate_mo_file_tranlation_service_if_file_exists
{
    my $self        = shift;
    my $target_lang = $self->{target_lang};
    my $domain      = $Petal::I18N::Domain || 'default';

    my $locale_dir = $self->{locale_dir};
    $locale_dir    =~ s/\/$//;
   
    my $mo_file_relative_path = "/$target_lang/LC_MESSAGES/$domain.mo";
    my $mo_file_absolute_path = $locale_dir . $mo_file_relative_path;

   -e $mo_file_absolute_path or return;
   return Petal::TranslationService::MOFile->new ($mo_file_absolute_path);
}


1;


__END__
