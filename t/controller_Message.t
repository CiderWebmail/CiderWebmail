use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'CiderWebmail' }
BEGIN { use_ok 'CiderWebmail::Controller::Message' }

ok( request('/message')->is_success, 'Request should succeed' );


