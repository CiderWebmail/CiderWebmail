use strict;
use warnings;
use Test::More;
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};


my $uname = getpwuid $UID;
my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get( 'http://localhost/' );
$mech->submit_form(with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} });

$mech->get_ok('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

$mech->submit_form(
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => 'messagehandling-'.$unix_time,
        body        => 'messagehandling',
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );

# Find all message links:
# <a href="http://localhost/mailbox/INBOX/27668" onclick="return false" id="link_27668">

my @links = $mech->find_all_links(id_regex => qr{\Alink_\d+\z});

for my $link (@links) {
    $mech->get_ok($link->url);
    $mech->follow_link_ok({ url_regex => qr{http://localhost/.*/reply/sender/(\d+|root)\z} }, "replying");

    # check if address fields are filled like:
    # <input value="johann.aglas@atikon.com" name="to">
    # <input value="ss@atikon.com" name="from">

    check_email($mech, 'to');
    check_email($mech, 'from', 1);

    $mech->get_ok($link->url);

    $mech->follow_link_ok({ url_regex => qr{http://localhost/.*/forward/(\d+|root)\z} }, "forwarding");

    check_email($mech, 'from', 1);

    $mech->get_ok($link->url);

    $mech->follow_link_ok({ url_regex => qr{http://localhost/.*/reply/all/(\d+|root)\z} }, "reply to all");

    check_email($mech, 'to');
    check_email($mech, 'from', 1);

    $mech->get_ok($link->url);

    $mech->follow_link_ok({ url_regex => qr{/view_source} }, 'view source');

    $mech->get_ok($link->url);

    my @attachments = $mech->find_all_links(url_regex => qr{http://localhost/.*/attachment/\d+});
    foreach(@attachments) {
        $mech->get_ok($_->url, 'open attachment');
    }

    $mech->get_ok($link->url);

    my @sendto_links = $mech->find_all_links(url_regex => qr{http://localhost/.*/compose/?\?to=[a-z]});
    foreach(@sendto_links) {
        $mech->get_ok($_->url, 'sendto');
        check_email($mech, 'from');
        check_email($mech, 'to', 1);
    }
}

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Amessagehandling-$unix_time\z});

$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@messages = $mech->find_all_links( text_regex => qr{\Amessagehandling-$unix_time\z});
ok((@messages == 0), 'messages deleted');

sub check_email {
    my ($mech, $field, $empty) = @_;

    my $value = $mech->value(lc $field);
    $empty = $empty ? '^$|' :  '';
    like($value, qr($empty$RE{Email}{Address}), $mech->uri . ": '$field' field contains an email address");
}

done_testing;
