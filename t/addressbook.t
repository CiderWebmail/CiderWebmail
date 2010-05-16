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

my $unix_time = time();

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost/' );

$mech->submit_form_ok({ with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} } });

$mech->follow_link_ok({ url_regex => qr{/addressbook} }, 'open addressbook');
$mech->follow_link_ok({ url_regex => qr{/modify/add} }, 'open add contact form');

$mech->submit_form_ok({ with_fields => { firstname => "firstname-$unix_time", surname => "surname-$unix_time", email => "email-$unix_time\@example.com" } }, 'submit add contact form');

$mech->content_contains("<td>firstname-$unix_time surname-$unix_time<\/td>", 'firstname and surname correct');
$mech->content_contains("compose?to=email-$unix_time\@example.com", 'email address correct');

ok( $mech->content =~ m/email\-$unix_time\@example\.com\"\s+id=\"compose_(\d+)/xm );
my $id = ($1 or '');
like($id, '/^\d+$/', 'address book id is a number');

$mech->follow_link_ok({ id => "edit_$id" }, 'open edit form');

field_contains('id', $id);
field_contains('firstname', "firstname-$unix_time");
field_contains('surname', "surname-$unix_time");
field_contains('email', "email-$unix_time\@example.com");

$mech->submit_form_ok({ with_fields => { firstname => "firstname-edit-$unix_time", surname => "surname-edit-$unix_time", email => "email-edit-$unix_time\@example.com" } }, 'submit edit contact form');

$mech->content_contains("<td>firstname-edit-$unix_time surname-edit-$unix_time<\/td>", 'firstname and surname correct after edit');
$mech->content_contains("compose?to=email-edit-$unix_time\@example.com", 'email address correct after edit');

$mech->follow_link_ok({ id => "compose_$id" });

check_email($mech, 'to');
check_email($mech, 'from', 1);

$mech->back;

$mech->content_contains("compose_$id", 'contact is in address book');

$mech->follow_link_ok({ id => "delete_$id" });

$mech->content_lacks("compose_$id", 'contact deleted from address book');

$mech->get_ok('http://localhost/addressbook/modify/add?name=foo&email=foo@example.com');
field_contains('firstname', 'foo');
field_contains('email', 'foo@example.com');

$mech->get_ok('http://localhost/addressbook/modify/add?name=foo%20bar&email=foo@example.com');
field_contains('firstname', 'foo');
field_contains('surname', 'bar');
field_contains('email', 'foo@example.com');

done_testing;

sub check_email {
    my ($mech, $field, $empty) = @_;

    my $value = $mech->value(lc $field);
    $empty = $empty ? '^$|' :  '';
    like($value, qr($empty$RE{Email}{Address}), $mech->uri . ": '$field' field contains an email address");
}

sub field_contains {
    my ($field, $expected_value) = @_;

    ok((my $field_value = $mech->value($field)), 'get form field content');
    is($field_value, $expected_value, "$field contains $expected_value");
}
