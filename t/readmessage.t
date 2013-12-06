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
        sent_folder => 'Sent',
        subject     => 'readmessage-'.$unix_time,
        body        => 'readmessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Areadmessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/m;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

xpath_test {
    my ($tx_unread) = @_;
    $tx_unread->unlike("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is unread" );
};

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id, 'open message');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

xpath_test {
    my ($tx_read) = @_;
    $tx_read->like("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is read" );
};

cleanup_messages(["readmessage-$unix_time"]);

done_testing();
