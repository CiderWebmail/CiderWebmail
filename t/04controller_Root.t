use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;

$mech->follow_link_ok({ url_regex => qr{/mailboxes\z} });

$mech->follow_link_ok({ url_regex => qr{/logout\z} });

done_testing();
