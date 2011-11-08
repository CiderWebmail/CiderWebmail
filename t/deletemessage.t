use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

my $uname = getpwuid $UID;

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

#Login
$mech->get_ok( 'http://localhost/' );
$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });

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
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
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

$unix_time = time();
$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'deletemessage-'.$unix_time,
        body        => 'deletemessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my (@trash_messages) = $mech->find_all_links( text_regex => qr{\Adeletemessage-$unix_time\z});

ok((@trash_messages == 1), 'messages found');

$mech->get_ok($trash_messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@trash_messages = $mech->find_all_links( text_regex => qr{\Adeletemessage-$unix_time\z});

ok((@trash_messages == 0), 'messages deleted');

$mech->get_ok( 'http://localhost/mailbox/Trash?length=99999' );

$mech->content_contains('deletemessage-'.$unix_time, 'verify that message is in trash');

done_testing();
