use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use File::Spec;
use English qw(-no_match_vars);

my $uname = getpwuid $UID;

$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $attachment_file = File::Spec->catfile( 't', 'testattachment.txt' );

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'attachment-'.$unix_time,
        body        => 'attachment',
        attachment  => $attachment_file,
    },
});

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );

my (@messages) = $mech->find_all_links( text_regex => qr{\Aattachment-$unix_time\z});

ok((@messages == 1), 'messages found');

#attachment download
$mech->get_ok($messages[0]->url, 'open message');
$mech->follow_link_ok({ text_regex => qr{testattachment.txt} }, 'Open Attachment');
ok(($mech->content =~ m/testattachment-content/), 'verify attachment content');


#attachment download for forwarded message
$mech->get_ok($messages[0]->url.'/part/forward/root');

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'attachmentforward-'.$unix_time,
        body        => 'attachmentforward',
    },
}, 'forward message');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @forw_messages = $mech->find_all_links( text_regex => qr{\Aattachmentforward-$unix_time\z});
ok((@forw_messages == 1), 'messages found');

#attachment download
$mech->get_ok($forw_messages[0]->url, 'open message');
$mech->follow_link_ok({ text_regex => qr{testattachment.txt} }, 'Open Forwarded Attachment');

ok(($mech->content =~ m/testattachment-content/), 'verify attachment content');

$mech->get_ok($messages[0]->url.'/delete', "Delete message");
$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->content_lacks('attachment-'.$unix_time);

$mech->get_ok($forw_messages[0]->url.'/delete', "Delete message");
$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->content_lacks('attachmentforward-'.$unix_time);

done_testing();
