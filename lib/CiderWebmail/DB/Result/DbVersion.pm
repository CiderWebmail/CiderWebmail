use utf8;
package CiderWebmail::DB::Result::DbVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CiderWebmail::DB::Result::DbVersion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<db_version>

=cut

__PACKAGE__->table("db_version");

=head1 ACCESSORS

=head2 version

  data_type: 'int'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "version",
  { data_type => "int", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</version>

=back

=cut

__PACKAGE__->set_primary_key("version");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-07-29 00:19:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6bk6L0K8of2XLoX0FjpOwQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
