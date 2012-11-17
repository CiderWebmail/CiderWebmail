use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);

use charnames ':full';

my $uname = getpwuid $UID;

$mech->get_ok('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

my $body  = "HEBREW_ALEF_\N{HEBREW LETTER ALEF} ";
$body    .= "HEBREW_PE_\N{HEBREW LETTER PE} ";
$body    .= "HEBREW_NUN_\N{HEBREW LETTER NUN} ";
$body    .= "CHECK_\N{CHECK MARK}";
$body    .= "\n\n";
$body    .= "\N{HEBREW LETTER ALEF}\N{HEBREW LETTER PE}\N{HEBREW LETTER NUN}\n\n";

$mech->submit_form(
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'hebrew-test-'.$unix_time,
        body        => $body,
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );


my (@inbox_messages) = $mech->find_all_links( text_regex => qr{\Ahebrew-test-$unix_time});
ok((@inbox_messages == 1), 'messages found');
$mech->get_ok($inbox_messages[0]->url, 'open message');

$mech->content_like(qr/HEBREW_ALEF_\N{HEBREW LETTER ALEF}/, 'hebrew character alef');
$mech->content_like(qr/HEBREW_PE_\N{HEBREW LETTER PE}/, 'hebrew character pe');
$mech->content_like(qr/HEBREW_NUN_\N{HEBREW LETTER NUN}/, 'hebrew character nun');
$mech->content_like(qr/CHECK_\N{CHECK MARK}/, 'check mark');

$mech->content_like(qr{<div class='rtl'><br />\N{HEBREW LETTER ALEF}\N{HEBREW LETTER PE}\N{HEBREW LETTER NUN}<br /><br /></div>}, 'check right-to-left display');

cleanup_messages(["hebrew-test-$unix_time"]);

done_testing();
