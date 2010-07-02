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

$mech->get_ok( 'http://localhost/' );
$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });
$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'INBOX',
        subject     => 'movemessage-'.$unix_time,
        body        => 'movemessage',
    },
});

$mech->get_ok('http://localhost/mailbox/INBOX?length=99999');
my (@messages) = $mech->find_all_links( text_regex => qr{\Amovemessage-$unix_time\z});

ok((@messages == 1), 'messages found');

$mech->get_ok('http://localhost/create_folder');

$mech->submit_form_ok({
    with_fields => {
        name => 'testfolder-'.$unix_time,
    },
});

$mech->get_ok($messages[0]->url.'/move?target_folder=testfolder-'.$unix_time, "Move Message");

$mech->title_like(qr/INBOX/, 'got a folder view');
$mech->get_ok('http://localhost/mailbox/INBOX?length=99999');

@messages = $mech->find_all_links( text_regex => qr{\Amovemessage-$unix_time\z});

ok((@messages == 0), 'message gone from source folder');

$mech->get_ok('http://localhost/mailbox/testfolder-'.$unix_time);

@messages = $mech->find_all_links( text_regex => qr{\Amovemessage-$unix_time\z});

ok((@messages == 1), 'message found in target folder');

$mech->get_ok('http://localhost/mailbox/testfolder-'.$unix_time.'/delete');

$mech->get_ok('http://localhost/mailboxes');

$mech->content_lacks('testfolder-'.$unix_time);

done_testing();
