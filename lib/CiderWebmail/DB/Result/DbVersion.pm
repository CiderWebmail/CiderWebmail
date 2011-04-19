package CiderWebmail::DB::Result::DbVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CiderWebmail::DB::Result::DbVersion

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
__PACKAGE__->set_primary_key("version");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-04-19 22:10:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xCcMFo7HtoQz9rauno9ZsA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
