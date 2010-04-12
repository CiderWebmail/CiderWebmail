package CiderWebmail::View::Petal;

use Moose;

extends 'Catalyst::View::Petal';

use Petal::Utils qw( :default :hash );
use Petal::TranslationService::Gettext;

=head1 NAME

CiderWebmail::View::Petal - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=head1 METHODS

=head2 after COMPONENT

Create a translation service for the configured language.

=cut

my $translation_service;

after COMPONENT => sub {
    my ($self, $c) = @_;
    $translation_service = Petal::TranslationService::Gettext->new(
            domain => 'CiderWebmail',
            locale_dir => $c->config->{root} . '/locale',
            target_lang => $c->config->{language} || 'en',
        );
    return;
};

=head2 process

=cut

sub process {
    my ($self, $c) = @_;

    my $root = $c->config->{root};

    my $base_dir = ["$root/templates", $root];
    unshift @$base_dir, "$root/ajax" if ($c->req->param('layout') or '') eq 'ajax';
    $self->config(
        base_dir => $base_dir,
        translation_service => ($c->stash->{no_translation} ? undef : $translation_service),
    ); # this sets the global config, so we have to do it for every request

    $c->stash({
        uri_root                 => $c->uri_for('/'),
        uri_static               => $c->uri_for('/static'),
        condcomment_lt_ie7_start => '<!--[if lt IE 7]>',
        condcommentend           => '<![endif]-->',
    });

    $c->res->content_type('text/xml') if ($c->req->param('layout') or '') eq 'ajax';

    return $self->SUPER::process($c);
}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
