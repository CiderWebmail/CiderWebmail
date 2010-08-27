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
$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'ajaxmessage-'.$unix_time,
        body        => 'ajaxmessage-body-'.$unix_time,
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?layout=ajax&length=99999' );

my @messages = $mech->find_all_links( text_regex => qr{\Aajaxmessage-$unix_time\z});

$messages[0]->attrs->{id} =~ m/link_(\d+)/xms;

my $message_id = $1;

ok( (length($message_id) > 0), 'got message id');

my $tx_unread = Test::XPath->new(xml => $mech->content, is_html => 1);
$tx_unread->unlike("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is unread" );

$mech->get_ok('http://localhost/mailbox/INBOX/'.$message_id.'?layout=ajax', 'open message');

$mech->content_like(qr/ajaxmessage-body-$unix_time/, 'message body there');

$mech->get_ok( 'http://localhost/mailbox/INBOX?layout=ajax&length=99999' );

my $tx_read = Test::XPath->new(xml => $mech->content, is_html => 1);
$tx_read->like("//tr[\@id='message_$message_id']/\@class", qr/seen/, "message is read" );

$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?layout=ajax&length=99999' );

$mech->content_lacks('ajaxmessage-'.$unix_time);

done_testing();
