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
        subject     => 'replymessage-'.$unix_time,
        body        => 'replymessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Areplymessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/m;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id, 'open message');

$mech->follow_link_ok({ url_regex => qr{/reply/sender/root\z} }, "replying");

$mech->submit_form_ok({
    with_fields => {
        from => "$uname\@localhost",
    }
}, 'Send reply');


$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->content_like(qr/replymessage-$unix_time/, 'original message is there');
$mech->content_like(qr/Re: replymessage-$unix_time/, 'forwarded message is there');

xpath_test {
    my ($tx_answered) = @_;
    $tx_answered->like("//tr[\@id='message_$message_id']/\@class", qr/answered/, "message is flagged answered" );
};


my @fwd_messages = $mech->find_all_links( text_regex => qr{\ARe: replymessage-$unix_time\z});

$mech->get_ok($messages[0]->url.'/delete', "Delete message");
$mech->get_ok($fwd_messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );

$mech->content_lacks('replymessage-'.$unix_time);
$mech->content_lacks('Re: replymessage-'.$unix_time);

done_testing();
