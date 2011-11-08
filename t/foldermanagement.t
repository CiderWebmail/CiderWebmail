use strict;
use warnings;
use Test::More;
use Test::XPath;
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
$mech->follow_link_ok({ url_regex => qr{/mailboxes} }, 'open Manage folders');

$mech->get_ok( 'http://localhost/mailbox/INBOX/create_subfolder', 'open create testfolder');

my $unix_time = time();
$mech->submit_form_ok({
    with_fields => {
        name        => 'test-folder-'.$unix_time,
    },
}, 'submit create folder form');

$mech->get_ok( 'http://localhost/mailboxes', 'open Manage folders');

$mech->get_ok('http://localhost/mailboxes', 'open folder list');
$mech->content_contains('test-folder-'.$unix_time.'/delete', 'verify that testfolder exists');

$mech->get_ok('http://localhost/mailbox/INBOX.Testfolder/delete', 'delete Testfolder');

$mech->follow_link_ok({ url_regex => qr{/mailbox/INBOX.test-folder-$unix_time/delete} }, 'delete testfolder folder');

$mech->content_lacks('test-folder-'.$unix_time, 'verify deletion of tesfolder');

done_testing();
