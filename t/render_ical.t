use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);
use FindBin qw($Bin);

$ENV{CIDERWEBMAIL_NODISCONNECT} = 1;

use Catalyst::Test 'CiderWebmail';
use HTTP::Request::Common;

my ($response, $c) = ctx_request POST '/', [
    username => $ENV{TEST_USER},
    password => $ENV{TEST_PASSWORD},
];

my $unix_time = time();

open my $testmail, '<', "$Bin/testmessages/ICAL.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/icaltest-TIME/icaltest-$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });

my $uname = getpwuid $UID;

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'icaltest-'.$unix_time });

$mech->content_contains('<th colspan="2" class="heading">Bastille Day Party</th>', 'summary/summary');
$mech->content_contains('<td class="begin">1997-07-14, 17:00:00</td>', 'begin');
$mech->content_contains('<td class="end">1997-07-15, 03:59:59</td>', 'end');
$mech->content_contains('<td colspan="2">Description-first-line<br /></td>', 'description');

cleanup_messages(["icaltest-$unix_time"]);

done_testing();
