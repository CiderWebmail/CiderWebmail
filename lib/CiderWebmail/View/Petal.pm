package CiderWebmail::View::Petal;

use strict;
use warnings;
use parent 'Catalyst::View::Petal';

use Petal::Utils qw( :default );
=head1 NAME

CiderWebmail::View::Petal - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=head1 METHODS

=head2 process

=cut

sub process {
    my ($self, $c) = @_;

    my $root = $c->config->{root};

    my $base_dir = ["$root/templates", $root];
    unshift @$base_dir, "$root/ajax" if ($c->req->param('layout') or '') eq 'ajax';
    $self->config(base_dir => $base_dir); # this sets the global config, so we have to do it for every request

    $c->stash({
        uri_root => $c->uri_for('/'),
        uri_static => $c->uri_for('/static'),
    });

    $self->SUPER::process($c);
}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
