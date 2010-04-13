use strict;
use warnings;

use Test::More tests => 8;

use CiderWebmail::Part;
use MIME::Entity;

my $entity = MIME::Entity->build( Type => "text/plain", Encoding => "quoted-printable", Data => ["TextData"]);

ok( my $part = CiderWebmail::Part->new({ entity => $entity, }) );
is( $part->render, undef);
is( $part->message, undef);
is( $part->renderable, undef);
is( $part->content_type, undef);
is( $part->type, 'text/plain');
is( $part->as_string, 'TextData');
is( $part->subparts, 0);
