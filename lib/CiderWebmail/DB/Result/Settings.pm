package CiderWebmail::DB::Result::Settings;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("settings");
__PACKAGE__->add_columns(
  "user",
  { data_type => "varchar", is_nullable => 0, size => undef },
  "from_address",
  { data_type => "varchar", is_nullable => 0, size => undef },
  "sent_folder",
  { data_type => "varchar", is_nullable => 0, size => undef },
  "sort_order",
  { data_type => "varchar", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("user");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-06-29 18:09:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+dBadUv981RkGHU1eKULHQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
