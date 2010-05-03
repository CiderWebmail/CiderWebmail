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

plan tests => 10;

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
        subject     => 'searchmessage-'.$unix_time,
        body        => 'searchmessage',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999&filter=searchmessage-'.$unix_time, 'search request successful' );

$mech->content_like( qr/link_\d+\">searchmessage-$unix_time/, 'searchmessage' );

my @messages = $mech->find_all_links( text_regex => qr{\Asearchmessage-$unix_time\z});
$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost' );

$mech->content_lacks('searchmessage-'.$unix_time);
