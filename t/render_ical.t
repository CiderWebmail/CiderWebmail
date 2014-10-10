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


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ text => 'icaltest-'.$unix_time });

xpath_test {
    my ($tx) = @_;

    $tx->is("//th[\@class='heading']", 'Bastille Day Party', 'summary');
    $tx->is("//td[\@class='begin']", '1997-07-14, 17:00:00', 'begin');
    $tx->is("//td[\@class='end']", '1997-07-15, 03:59:59', 'end');
    $tx->is("//td[\@class='description']", 'Description-first-line', 'description');
};

cleanup_messages(["icaltest-$unix_time"]);

done_testing();
