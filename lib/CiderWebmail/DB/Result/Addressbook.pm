use utf8;
package CiderWebmail::DB::Result::Addressbook;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CiderWebmail::DB::Result::Addressbook

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<addressbook>

=cut

__PACKAGE__->table("addressbook");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user

  data_type: 'varchar'
  is_nullable: 0

=head2 firstname

  data_type: 'varchar'
  is_nullable: 0

=head2 surname

  data_type: 'varchar'
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user",
  { data_type => "varchar", is_nullable => 0 },
  "firstname",
  { data_type => "varchar", is_nullable => 0 },
  "surname",
  { data_type => "varchar", is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-02 15:57:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:95AmK1KOBcaKGpuzXxTklQ

# You can replace this text with custom content, and it will be preserved on regeneration
1;
