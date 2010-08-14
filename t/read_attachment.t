use strict;
use warnings;
use Test::More;
use File::Spec;
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
$mech->get_ok($messages[0]->url.'/forward');

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
