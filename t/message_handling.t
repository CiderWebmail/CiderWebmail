use strict;
use warnings;
use Test::More;
use Regexp::Common qw(Email::Address);
use Email::Address;

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

my $mech = Test::WWW::Mechanize->new;

$mech->credentials('test@atikon.at', 'quech0Ae');
$mech->get( 'http://localhost:3000/' )->is_success or die 'This test requires a running Catalyst server on port 3000. Recommending using the -fork option!';

# Find all message links:
# <a href="http://localhost/mailbox/INBOX/27668" onclick="return false" id="link_27668">

my @links = $mech->find_all_links(id_regex => qr{\Alink_\d+\z});
plan tests => 9 * @links;

for my $link (@links) {
    $mech->get_ok($link->url);
    $mech->follow_link_ok({ url_regex => qr{/reply/sender\z} }, "replying");

    # check if address fields are filled like:
    # <input value="johann.aglas@atikon.com" name="to">
    # <input value="ss@atikon.com" name="from">

    unless ($mech->content_like(qr/<input value="$RE{Email}{Address}" name="to">/, 'To: field does not contain an email address')) {
        warn $link->url, ': ', $mech->content =~ m'(<input value="[^"]+" name="to">)';
    }
    unless ($mech->content_like(qr/<input value="$RE{Email}{Address}" name="from">/, 'From: field does not contain an email address')) {
        warn $link->url, ': ', $mech->content =~ m'(<input value="[^"]+" name="from">)';
    }

    $mech->back;

    $mech->follow_link_ok({ url_regex => qr{/forward\z} }, "forwarding");

    unless ($mech->content_like(qr/<input value="$RE{Email}{Address}" name="from">/, 'From: field does not contain an email address')) {
        warn $link->url, ': ', $mech->content =~ m'(<input value="[^"]+" name="from">)';
    }

    $mech->back;

    $mech->follow_link_ok({ url_regex => qr{/reply/all\z} }, "reply to all");

    unless ($mech->content_like(qr/<input value="$RE{Email}{Address}(?:\s*;\s*$RE{Email}{Address})*" name="to">/, 'To: field does not contain an email address')) {
        warn $link->url, ': ', $mech->content =~ m'(<input value="[^"]+" name="to">)';
    }

    unless ($mech->content_like(qr/<input value="$RE{Email}{Address}" name="from">/, 'From: field does not contain an email address')) {
        warn $link->url, ': ', $mech->content =~ m'(<input value="[^"]+" name="from">)';
    }
}
