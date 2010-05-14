package CiderWebmail::Model::DB;

use strict;
use warnings;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'CiderWebmail::DB',
    connect_info => [
        'dbi:SQLite:root/var/user_settings.sql',
        
    ],
);

=head1 NAME

CiderWebmail::Model::DB - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<CiderWebmail>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<CiderWebmail::DB>

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
