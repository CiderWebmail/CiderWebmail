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

plan tests => 14;

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
        subject     => 'rfc822test-'.$unix_time,
        body        => 'rfc822test',
    },
});

my @messages = $mech->find_all_links( text_regex => qr{\Arfc822test-$unix_time\z});
$mech->get_ok($messages[0]->url.'/forward');

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'INBOX',
        subject     => 'rfc822forwarded-'.$unix_time,
        body        => 'rfc822forwarded',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX/' );
@messages = $mech->find_all_links( text_regex => qr{\Arfc822forwarded-$unix_time\z});
$mech->get_ok( $messages[0]->url );
$mech->content_contains('<h1>rfc822test-'.$unix_time.'</h1>');

$mech->get_ok( 'http://localhost/mailbox/INBOX/' );
@messages = $mech->find_all_links( text_regex => qr{\Arfc822(test|forwarded)-$unix_time\z});
ok((@messages == 2), 'messages found');
$mech->get_ok($messages[0]->url.'/delete', "Delete message");
$mech->get_ok($messages[1]->url.'/delete', "Delete message");




