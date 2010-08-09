use strict;
use warnings;
use Test::More;
use Regexp::Common qw(Email::Address);
use Email::Address;
use WWW::Mechanize;

use English qw(-no_match_vars);

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};
return plan skip_all => 'Set VALIDATOR_URI to a server runnint the w3c validator for xhml validation tests' unless $ENV{VALIDATOR_URI};

my $uname = getpwuid $UID;
my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get( 'http://localhost/' );
$mech->submit_form(with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} }); #FIXME should be a test, too, but we don't know the test plan yet...

$mech->get('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

$mech->submit_form(
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'INBOX',
        subject     => 'utf8handling-'.$unix_time,
        body        => 'utf8handling',
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );

# Find all message links:
# <a href="http://localhost/mailbox/INBOX/27668" onclick="return false" id="link_27668">

my @links = $mech->find_all_links(id_regex => qr{\Alink_\d+\z});

my $v = Test::WWW::Mechanize->new();
for my $link (@links) {
    $mech->get_ok($link->url);

    $v->get_ok($ENV{VALIDATOR_URI});
    $v->submit_form(
        with_fields => {
            fragment => $mech->content,
        }
    );

    $v->content_contains('This document was successfully checked as', "XHTML validation failed for ".$link->url);
}

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Autf8handling-$unix_time\z});

$mech->get_ok($messages[0]->url.'/delete', "Delete message");

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
@messages = $mech->find_all_links( text_regex => qr{\Autf8handling-$unix_time\z});
ok((@messages == 0), 'messages deleted');

done_testing();
