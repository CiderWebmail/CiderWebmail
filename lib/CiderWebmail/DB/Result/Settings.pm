package CiderWebmail::DB::Result::Settings;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

CiderWebmail::DB::Result::Settings

=cut

__PACKAGE__->table("settings");

=head1 ACCESSORS

=head2 user

  data_type: varchar
  default_value: undef
  is_nullable: 0
  size: undef

=head2 from_address

  data_type: varchar
  default_value: undef
  is_nullable: 1
  size: undef

=head2 sent_folder

  data_type: varchar
  default_value: undef
  is_nullable: 1
  size: undef

=head2 sort_order

  data_type: varchar
  default_value: undef
  is_nullable: 1
  size: undef

=cut

__PACKAGE__->add_columns(
  "user",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 0,
    size => undef,
  },
  "from_address",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "sent_folder",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
  "sort_order",
  {
    data_type => "varchar",
    default_value => undef,
    is_nullable => 1,
    size => undef,
  },
);
__PACKAGE__->set_primary_key("user");


# Created by DBIx::Class::Schema::Loader v0.05003 @ 2010-05-15 15:15:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U90R/881k4x0S6hHELkH5Q

=head1 CiderWebmail::DB::Result::Settings

Class representing the settings table in the DB

=cut

1;
