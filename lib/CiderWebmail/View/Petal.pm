package CiderWebmail::View::Petal;

use Moose;

extends 'Catalyst::View::Petal';

use Petal::Utils qw( :default :hash );

=head1 NAME

CiderWebmail::View::Petal - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=head1 METHODS

=head2 process

=cut

__PACKAGE__->config(input => 'XHTML', output => 'XHTML');

sub process {
    my ($self, $c) = @_;

    my $root = $c->config->{root};

    my $base_dir = ["$root/templates", $root];
    unshift @$base_dir, "$root/ajax" if ($c->req->param('layout') or '') eq 'ajax';
    $self->config(
        base_dir => $base_dir,
        translation_service => ($c->stash->{no_translation} ? undef : $c->stash->{translation_service}),
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

=head2 render_template()

renders a template

=cut

sub render_template {
    my ($self, $o) = @_;

    my $root = $o->{c}->config->{root};
    my $base_dir = ["$root/templates/parts"];

    my $template = Petal->new( base_dir => $base_dir, file => $o->{template});
    my $output = $template->process( $o->{stash} );
    $output =~ s/[^\x01-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//gxmo;
    $output =~    s/[\x01-\x08\x0B-\x0C\x0E-\x1F\x7F-\x84\x86-\x9F]//gxmo;
    return $output;
}


=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
