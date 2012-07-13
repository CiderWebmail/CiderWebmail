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

open my $testmail, '<', "$Bin/testmessages/TEXT.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/textmessage-TIME/textmessage-$unix_time/gm;
$message_text =~ s/testsignature-TIME/testsignature-$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });

my $uname = getpwuid $UID;

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'textmessage-'.$unix_time });

$mech->content_contains('<div class="renderable monospace">textmessage <a href="http://example.com">http://example.com</a>', 'check content for URI to HTML link conversion');
$mech->content_contains("textmessage-$unix_time line that is so long that it should get wrapped<br />by the Text::Autoformat module", 'check content for text wrapping by Text::Autoformat');
$mech->content_contains("testsignature-$unix_time signature line that is so long but still should not get wrapped by the Text::Autoformat module", 'check content for signature handling by Text::Autoformat');


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Atextmessage-$unix_time\z});
ok((@messages == 1), 'messages found');
$mech->get_ok($messages[0]->url.'/delete', "Delete message");

done_testing();
