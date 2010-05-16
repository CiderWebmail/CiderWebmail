package CiderWebmail::DB::Result::Addressbook;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

CiderWebmail::DB::Result::Addressbook

=cut

__PACKAGE__->table("addressbook");

=head1 ACCESSORS

=head2 id

  data_type: INTEGER
  default_value: undef
  is_nullable: 1
  size: undef

=head2 user

  data_type: varchar
  default_value: undef
  is_nullable: 0
  size: undef

=head2 firstname

  data_type: varchar
  default_value: undef
  is_nullable: 0
  size: undef

=head2 surname

  data_type: varchar
  default_value: undef
  is_nullable: 0
  size: undef

=head2 email

  data_type: varchar
  default_value: undef
  is_nullable: 0
  size: undef

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "INTEGER",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "user",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "firstname",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "surname",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "email",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.05003 @ 2010-05-16 11:24:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1CK737mFEQIDjz/MgHnp7g

# You can replace this text with custom content, and it will be preserved on regeneration
1;
