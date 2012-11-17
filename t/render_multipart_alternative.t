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

open my $testmail, '<', "$Bin/testmessages/MULTIPART_ALTERNATIVE.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/TIME/$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });

my $uname = getpwuid $UID;

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'multipart-alternative-TestMail-'.$unix_time });

#verify that we only display the text/html part since it is the preferred_alternative
$mech->content_lacks('TestMail-PLAIN-'.$unix_time, 'content lacks text/plain part');

xpath_test {
    my ($tx) = @_;
    $tx->ok("//div[\@class='html_message renderable']/iframe", sub { #check for iframe itself
        $_->ok( './@src', qr{\d+/part/render/\d+}, sub { #check for render url
            my $iframe_src = $_->node->textContent;
            $mech->get($iframe_src);

            $mech->content_contains("<b>TestMail-HTML-$unix_time</b>", 'verify HTML in iframe');
        }, 'found iframe render url');
    }, 'found iframe for html content' );
};


cleanup_messages(["multipart-alternative-TestMail-$unix_time"]);

done_testing();
