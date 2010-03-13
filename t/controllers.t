use strict;
use warnings;
use Test::More;
use Regexp::Common qw(Email::Address);
use Email::Address;
use MIME::Lite;
use English qw(-no_match_vars);

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

my $sent_mail;

MIME::Lite->send(sub => sub {
    my ($self) = @_;

    $sent_mail = {
        to   => $self->get('to'),
        body => $self->as_string,
    };
});

plan tests => 24;

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost/' );

$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });

$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $uname = getpwuid $UID;

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'INBOX',
        subject     => 'testmessage1',
        body        => 'foo bar baz',
    },
});

# Find all message links:
# <a href="http://localhost/mailbox/INBOX/27668" onclick="return false" id="link_27668">

my @links = $mech->find_all_links(id_regex => qr{\Alink_\d+\z});

my $link = $links[0];

$mech->get_ok($link->url);
$mech->follow_link_ok({ url_regex => qr{/reply/sender/?\z} }, "replying");

# check if address fields are filled like:
# <input value="johann.aglas@atikon.com" name="to">
# <input value="ss@atikon.com" name="from">

check_email($mech, 'to');
check_email($mech, 'from', 1);

$mech->submit_form_ok({ button => 'send' }, 'Send reply');
ok($sent_mail, 'We sent some mail');
ok($sent_mail->{to}, 'We got some To');
my $mail = MIME::Parser->new();
undef $sent_mail;

$mech->back;
$mech->back;

$mech->follow_link_ok({ url_regex => qr{/forward/?\z} }, "forwarding");

check_email($mech, 'from', 1);

$mech->submit_form_ok({ button => 'send' }, 'Send forward');
ok($sent_mail, 'We sent some mail');
undef $sent_mail;

$mech->back;
$mech->back;

$mech->follow_link_ok({ url_regex => qr{/reply/all/?\z} }, "reply to all");

check_email($mech, 'to');
check_email($mech, 'from', 1);

$mech->back;

$mech->follow_link_ok({ url_regex => qr{/view_source} }, 'view source');

$mech->get_ok( 'http://localhost:3000/mailbox/INBOX/compose' );

my $searchmessage_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'INBOX',
        subject     => 'searchmessage-'.$searchmessage_time,
        body        => 'searchmessage',
    },
});

$mech->get_ok( 'http://localhost:3000/mailbox/INBOX?filter=searchmessage-'.$searchmessage_time, 'search request successful' );

$mech->content_like( qr/link_\d+\">searchmessage-$searchmessage_time/, 'searchmessage' );

sub check_email {
    my ($mech, $field, $empty) = @_;

    my $value = $mech->value(lc $field);
    $empty = $empty ? '^$|' :  '';
    like($value, qr($empty$RE{Email}{Address}), $mech->uri . ": '$field' field contains an email address");
}
