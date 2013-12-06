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
$message_text =~ s/TIME/$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'textmessage-'.$unix_time });

$mech->follow_link_ok({ url_regex => qr{http://localhost/.*/reply/list/(\d+|root)\z} }, 'open list reply url');

xpath_test {
    my ($tx) = @_;
    $tx->is("//label[\@class='to']/input/\@value", "list-post-$unix_time-test\@example.com", "to address is correctly set to list address");
};

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'textmessage-'.$unix_time });
$mech->follow_link_ok({ url_regex => qr{/forward/root\z} }, "forwarding");

$mech->submit_form_ok({
    with_fields => {
        to => $ENV{TEST_MAILADDR},
    }
}, 'Send forward');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->follow_link_ok({ text => 'Fwd: textmessage-'.$unix_time }, 'found forwarded message');

$mech->follow_link_ok({ url_regex => qr{http://localhost/.*/reply/list/(\d+|root)\z} }, 'open list reply url');
xpath_test {
    my ($tx) = @_;
    $tx->is("//label[\@class='to']/input/\@value", "list-post-$unix_time-test\@example.com", "to address is correctly set to list address");
};

cleanup_messages(["Fwd: textmessage-$unix_time", "textmessage-$unix_time"]);

done_testing();
