use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'CiderWebmail' }
BEGIN { use_ok 'CiderWebmail::Controller::Addressbook' }

ok( request('/addressbook')->is_success, 'Request should succeed' );
done_testing();
