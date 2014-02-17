use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use CiderWebmail::Test {login => 1};


$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => find_special_folder('sent'),
        subject     => 'importantmessage-'.$unix_time,
        body        => 'importantmessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Aimportantmessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/m;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

xpath_test {
    my ($tx_unread) = @_;
    $tx_unread->unlike("//tr[\@id='message_$message_id']/\@class", qr/flagged/, "message is not flagged in mailbox list" );
};

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id, 'open message');
$mech->content_contains('/images/flag.png', 'flag is not set');

$mech->follow_link_ok({ url_regex => qr{/toggle_important$} }, 'toggle flag');
$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id, 'open message');
$mech->content_contains('/images/flag-red.png', 'flag is now set');


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

xpath_test {
    my ($tx_unread) = @_;
    $tx_unread->like("//tr[\@id='message_$message_id']/\@class", qr/flagged/, "message is now flagged in mailbox list" );
};

cleanup_messages(["importantmessage-$unix_time"]);

done_testing();
