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

open my $testmail, '<', "$Bin/testmessages/HTML.mbox";
my $message_text = join '', <$testmail>;
$message_text =~ s/htmltest-TIME/htmltest-$unix_time/gm;

$c->model('IMAPClient')->append_message({ mailbox => 'INBOX', message_text => $message_text });

my $uname = getpwuid $UID;

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'htmltest-'.$unix_time });

xpath_test {
    my ($tx) = @_;
    $tx->ok("//div[\@class='html_message renderable']/iframe", sub { #check for iframe itself
        $_->ok( './@src', qr{\d+/part/render/\d+}, sub { #check for render url
            my $iframe_src = $_->node->textContent;
            $mech->get($iframe_src);

            #at this point $mech->content returnes the content of the iframe
            
        }, 'found iframe render url');
    }, 'found iframe for html content' );
};


#TODO more complicated HTML mail
$mech->content_contains('<p style="margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px; -qt-user-state:0;"><b>This is an HTML testmail.</b></p>', 'HTML content in iframe');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Ahtmltest-$unix_time\z});
ok((@messages == 1), 'messages found');
$mech->get_ok($messages[0]->url.'/delete', "Delete message");

done_testing();
