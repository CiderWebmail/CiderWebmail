use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);

my $unix_time = time();

#attempt to delete trash folder if it exists
if (my $trash_folder = find_special_folder('trash')) {
    $mech->get_ok("http://localhost/mailbox/$trash_folder/delete", 'delete Trash folder');
}

#we attempted to delete the trash folder, but it is still there
#some IMAP servers will 'force' a trash folder, so we skip the 
#delete-without-trash tests here
if (my $trash_folder = find_special_folder('trash')) {
#Test without Trash folder (directly delete message)
    $mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
    $mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

    $mech->submit_form_ok({
        with_fields => {
            from        => $ENV{TEST_MAILADDR},
            to          => $ENV{TEST_MAILADDR},
            sent_folder => find_special_folder('sent'),
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
} else {
    #we have no trash folder, create one

    $mech->get_ok('http://localhost/mailboxes');

    #this is not perfect but works with default dovecot&courier installations until we finish support for special use mailboxes
    $mech->follow_link_ok({ url_regex => qr{INBOX/create_subfolder} }, 'Follow create subfolder link');

    $mech->submit_form_ok({
        with_fields => {
            name => 'Trash',
        },
    }, 'create Trash folder');
}

#Test with Trash folder, move message to Trash
my $trash_folder = find_special_folder('trash');

$mech->get_ok('http://localhost/mailboxes', 'open folder list');
$mech->content_contains("/mailbox/$trash_folder", 'verify that Trash folder exists');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => find_special_folder('sent'),
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

$mech->get_ok( "http://localhost/mailbox/$trash_folder?length=99999" );

$mech->content_contains('trash_deletemessage-'.$unix_time, 'verify that message is in trash');

cleanup_messages(["deletemessage-$unix_time", "trash_deletemessage-$unix_time"]);

done_testing();
