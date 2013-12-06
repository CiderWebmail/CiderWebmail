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

open my $testmail, '<', "$Bin/testmessages/IMAGE_JPEG.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/TIME/$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'testmessage-image-attachment-'.$unix_time }, 'follow testmessage-image-attachment link');

my @render_links = $mech->find_all_links(url_regex => qr{http://localhost/.*/render/.*});
ok((@render_links == 1), 'one render link found');
foreach(@render_links) {
    $mech->get_ok($_->url, "Fetch ".$_->url);
    $mech->content_like(qr!<h1>test\.jpg</h1>!, 'found image name');
    $mech->content_like(qr!part/download/2!, 'found image link');
}

cleanup_messages(["testmessage-image-attachment-$unix_time"]);

done_testing();
