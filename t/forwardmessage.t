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
        subject     => 'forwardmessage-'.$unix_time,
        body        => 'forwardmessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Aforwardmessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/m;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id, 'open message');

$mech->follow_link_ok({ url_regex => qr{/forward/root\z} }, "forwarding");

$mech->submit_form_ok({
    with_fields => {
        to => "$uname\@localhost",
    }
}, 'Send forward');


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->content_like(qr/forwardmessage-$unix_time/, 'original message is there');
$mech->content_like(qr/Fwd: forwardmessage-$unix_time/, 'forwarded message is there');

my @fwd_messages = $mech->find_all_links( text_regex => qr{\AFwd: forwardmessage-$unix_time\z});

$mech->get_ok($messages[0]->url.'/delete', "Delete message");
$mech->get_ok($fwd_messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->content_lacks('forwardmessage-'.$unix_time);
$mech->content_lacks('Fwd: forwardmessage-'.$unix_time);

done_testing();
