use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);


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
