use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use FindBin qw($Bin);

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};

$ENV{CIDERWEBMAIL_NODISCONNECT} = 1;

use Catalyst::Test 'CiderWebmail';
use HTTP::Request::Common;

my ($response, $c) = ctx_request POST '/', [
    username => $ENV{TEST_USER},
    password => $ENV{TEST_PASSWORD},
];

open my $testmail, '<', "$Bin/testmessages/HTML.mbox";

$c->model('IMAPClient')->append_message($c, { mailbox => 'INBOX', message_text => join '', <$testmail>});

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

my $uname = getpwuid $UID;

plan tests => 4;

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost/' );
$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });
$mech->follow_link_ok({ text => 'HTML-Testmail' });
