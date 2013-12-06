use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use WWW::Mechanize;

use English qw(-no_match_vars);

return plan skip_all => 'Set VALIDATOR_URI to a server running the w3c validator for HTML5 validation tests' unless $ENV{VALIDATOR_URI};


$mech->get('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

$mech->submit_form(
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => 'Sent',
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

    $v->content_contains('This document was successfully checked as', "HTML5 validation OK for ".$link->url);
}

delete_messages(["utf8handling-$unix_time"]);

done_testing();
