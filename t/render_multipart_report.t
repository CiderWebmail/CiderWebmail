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

open my $testmail, '<', "$Bin/testmessages/MULTIPART_REPORT.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/dsnmessage-TIME/dsnmessage-$unix_time/gm;
$message_text =~ s/dsnmessage-check-header-TIME/dsnmessage-check-header-$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });

my $uname = getpwuid $UID;

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'dsnmessage-'.$unix_time });

$mech->content_contains("dsnmessage-check-header-$unix_time", 'check content');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Adsnmessage-$unix_time\z});
ok((@messages == 1), 'messages found');
$mech->get_ok($messages[0]->url.'/delete', "Delete message");

done_testing();
