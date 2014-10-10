use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);

my $unix_time = time();

$mech->follow_link_ok({ url_regex => qr{/addressbook} }, 'open addressbook');
$mech->follow_link_ok({ url_regex => qr{/modify/add} }, 'open add contact form');

$mech->submit_form_ok({ with_fields => { firstname => "firstname-$unix_time", surname => "surname-$unix_time", email => "email-$unix_time\@example.com" }, button => 'update' }, 'submit add contact form');

$mech->content_contains("<td>firstname-$unix_time surname-$unix_time<\/td>", 'firstname and surname correct');
$mech->content_contains("compose?to=email-$unix_time\@example.com", 'email address correct');

my $id = undef;
xpath_test {
    my ($tx) = @_;
    $tx->ok("//a[contains(\@href, 'email-$unix_time')]", sub {
        $_->ok('./@id', sub {
            if ($_->node->textContent =~ m/^compose_(\d+)$/) {
                $id = $1;
                return 1;
            }
        });
    }, 'found address entry A element');
};

$mech->follow_link_ok({ id => "edit_$id" }, 'open edit form');

field_contains('id', $id);
field_contains('firstname', "firstname-$unix_time");
field_contains('surname', "surname-$unix_time");
field_contains('email', "email-$unix_time\@example.com");

$mech->submit_form_ok({ with_fields => { firstname => "firstname-edit-$unix_time", surname => "surname-edit-$unix_time", email => "email-edit-$unix_time\@example.com" }, button => 'update' }, 'submit edit contact form');

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
