use utf8;
package CiderWebmail::DB::Result::Settings;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CiderWebmail::DB::Result::Settings

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<settings>

=cut

__PACKAGE__->table("settings");

=head1 ACCESSORS

=head2 user

  data_type: 'varchar'
  is_nullable: 0

=head2 from_address

  data_type: 'varchar'
  is_nullable: 1

=head2 sent_folder

  data_type: 'varchar'
  is_nullable: 1

=head2 sort_order

  data_type: 'varchar'
  is_nullable: 1

=head2 signature

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user",
  { data_type => "varchar", is_nullable => 0 },
  "from_address",
  { data_type => "varchar", is_nullable => 1 },
  "sent_folder",
  { data_type => "varchar", is_nullable => 1 },
  "sort_order",
  { data_type => "varchar", is_nullable => 1 },
  "signature",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user>

=back

=cut

__PACKAGE__->set_primary_key("user");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-11-02 15:57:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QP4m8CWyVxIsbxnUSS7WVg

=head1 CiderWebmail::DB::Result::Settings

Class representing the settings table in the DB

=cut

1;
