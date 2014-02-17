use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);


$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => find_special_folder('sent'),
        subject     => 'rfc822test-'.$unix_time,
        body        => 'rfc822test',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Arfc822test-$unix_time\z});
$mech->get_ok($messages[0]->url.'/part/forward/root');

$mech->submit_form_ok({
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => find_special_folder('sent'),
        subject     => 'rfc822forwarded-'.$unix_time,
        body        => 'rfc822forwarded',
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@messages = $mech->find_all_links( text_regex => qr{\Arfc822forwarded-$unix_time\z});
$mech->get_ok( $messages[0]->url );
$mech->content_contains('<h1>rfc822test-'.$unix_time.'</h1>');

cleanup_messages(["rfc822test-$unix_time", "rfc822forwarded-$unix_time"]);

done_testing();
