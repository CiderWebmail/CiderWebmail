use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);

my $uname = getpwuid $UID;

$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'ajaxmessage-'.$unix_time,
        body        => 'ajaxmessage-body-'.$unix_time,
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?layout=ajax&length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Aajaxmessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/xms;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

xpath_test {
    my ($tx_unread) = @_;
    $tx_unread->unlike("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is unread" );
};

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id.'?layout=ajax', 'open message');

$mech->content_like(qr/ajaxmessage-body-$unix_time/, 'message body there');

$mech->get_ok( 'http://localhost/mailbox/INBOX?layout=ajax&length=99999' );

xpath_test {
    my ($tx_read) = @_;
    $tx_read->like("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is read" );
};

cleanup_messages(["ajaxmessage-$unix_time"]);

done_testing();
