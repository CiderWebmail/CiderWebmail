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

$messages[0]->attrs->{id} =~ m/link_(\d+)/m;
my $message_id = $1;
ok( (length($message_id) > 0), 'got message id');

xpath_test {
    my ($tx) = @_;
    $tx->ok("//tr[\@id='message_$message_id']/td[\@class='icons']/img[\@class='attachment_icon']", "attachment icon is set" );
};



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

$forw_messages[0]->attrs->{id} =~ m/link_(\d+)/m;
my $forw_message_id = $1;
ok( (length($forw_message_id) > 0), 'got forwarded message id');

xpath_test {
    my ($tx_fwd) = @_;
    $tx_fwd->not_ok("//tr[\@id='message_$forw_message_id']/td[\@class='icons']/img[\@class='attachment_icon']", "check that attachment icon is not set for forwarded message" );
};



#attachment download
$mech->get_ok($forw_messages[0]->url, 'open message');

#verify that we do not render the attachment content - we could render it because it is text/plain but do not because it's disposition is 'attachment'
$mech->content_lacks('testattachment-content', 'verify that we do not render the attachment content');

$mech->follow_link_ok({ text_regex => qr{testattachment.txt} }, 'Open Forwarded Attachment');

ok(($mech->content =~ m/testattachment-content/), 'verify attachment content');

$mech->get_ok($messages[0]->url.'/delete', "Delete message");
$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->content_lacks('attachment-'.$unix_time);

$mech->get_ok($forw_messages[0]->url.'/delete', "Delete message");
$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
$mech->content_lacks('attachmentforward-'.$unix_time);

done_testing();
