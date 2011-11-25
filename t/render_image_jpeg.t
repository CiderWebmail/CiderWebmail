use strict;
use warnings;
use Test::More;
use Test::XPath;
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

my $unix_time = time();

open my $testmail, '<', "$Bin/testmessages/IMAGE_JPEG.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/TIME/$unix_time/gm;

$c->model('IMAPClient')->append_message($c, { mailbox => 'INBOX', message_text => $message_text });

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

my $uname = getpwuid $UID;

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost/' );
$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'testmessage-image-attachment-'.$unix_time }, 'follow testmessage-image-attachment link');

my @render_links = $mech->find_all_links(url_regex => qr{http://localhost/.*/render/.*});
ok((@render_links == 1), 'one render link found');
foreach(@render_links) {
    $mech->get_ok($_->url, "Fetch ".$_->url);
    $mech->content_like(qr!<h1>test\.jpg</h1>!, 'found image name');
    $mech->content_like(qr!part/download/2!, 'found image link');
}

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Atestmessage-image-attachment-$unix_time\z});
ok((@messages == 1), 'messages found');
$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->content_lacks('testmessage-image-attachment-'.$unix_time, 'verify that messages got deleted');

done_testing();
