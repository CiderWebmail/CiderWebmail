use strict;
use warnings;

use Test::More;
use CiderWebmail::Test {test_user => 1};

$mech->get( 'http://localhost/' );
$mech->submit_form(with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} . rand(999) });
$mech->content_contains('Invalid username or password.', 'check login with invalid credentials');

done_testing();
