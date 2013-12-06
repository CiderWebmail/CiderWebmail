use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);


#delete trash folder if it exists
$mech->get_ok('http://localhost/mailboxes', 'open folder list');
if ($mech->content =~ m{mailbox/Trash/delete}) {
    $mech->follow_link_ok({ url_regex => qr{/mailbox/Trash/delete} }, 'delete Trash folder');
}

$mech->content_lacks('/Trash/', 'verify that there is no trashfolder');

my $unix_time = time();

#Test without Trash folder (directly delete message)
$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => 'Sent',
        subject     => 'deletemessage-'.$unix_time,
        body        => 'deletemessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my (@messages) = $mech->find_all_links( text_regex => qr{\Adeletemessage-$unix_time\z});

ok((@messages == 1), 'messages found');

$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@messages = $mech->find_all_links( text_regex => qr{\Adeletemessage-$unix_time\z});

ok((@messages == 0), 'messages deleted');

#Test with Trash folder, move message to Trash
$mech->get_ok('http://localhost/create_folder');

$mech->submit_form_ok({
    with_fields => {
        name => 'Trash',
    },
}, 'create Trash folder');

$mech->get_ok('http://localhost/mailboxes', 'open folder list');
$mech->content_contains('/mailbox/Trash/delete', 'verify that Trash folder exists');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => 'Sent',
        subject     => 'trash_deletemessage-'.$unix_time,
        body        => 'trash_deletemessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my (@trash_messages) = $mech->find_all_links( text_regex => qr{\Atrash_deletemessage-$unix_time\z});

ok((@trash_messages == 1), 'messages found');

$mech->get_ok($trash_messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@trash_messages = $mech->find_all_links( text_regex => qr{\Atrash_deletemessage-$unix_time\z});

ok((@trash_messages == 0), 'messages deleted');

$mech->get_ok( 'http://localhost/mailbox/Trash?length=99999' );

$mech->content_contains('trash_deletemessage-'.$unix_time, 'verify that message is in trash');

cleanup_messages(["deletemessage-$unix_time", "trash_deletemessage-$unix_time"]);

done_testing();
