use strict;
use warnings;
use Test::More;


use Catalyst::Test 'CiderWebmail';
use CiderWebmail::Controller::Managesieve;

ok( request('/managesieve')->is_success, 'Request should succeed' );
done_testing();
