use utf8;
package CiderWebmail::DB::Result::RecentContacts;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CiderWebmail::DB::Result::RecentContacts

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<recent_contacts>

=cut

__PACKAGE__->table("recent_contacts");

=head1 ACCESSORS

=head2 user

  data_type: 'varchar'
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0

=head2 last_used

  data_type: 'date'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "user",
  { data_type => "varchar", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0 },
  "email",
  { data_type => "varchar", is_nullable => 0 },
  "last_used",
  { data_type => "date", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user>

=item * L</email>

=back

=cut

__PACKAGE__->set_primary_key("user", "email");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-07-29 00:41:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8XejaYHnu66XKGWCsvzmew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
