use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);

use JSON::XS;

my $unix_time = time();

check_error('send-mail-error-no-recipients', { from => $ENV{TEST_MAILADDR}, to => '', sent_folder => 'Sent', subject => 'compose-message-test-'.$unix_time, body => 'compose-message-body-'.$unix_time, });
check_error('send-mail-error-no-sender', { from => '', to => $ENV{TEST_MAILADDR}, sent_folder => 'Sent', subject => 'compose-message-test-'.$unix_time, body => 'compose-message-body-'.$unix_time, });

sub check_error {
    my ($expected_error, $fields) = @_;

    $mech->get_ok('http://localhost/mailbox/INBOX/compose');
    ok($mech->status eq '200', 'loadcompose form');

    $mech->form_with_fields(qw/ from to cc subject /);

    $fields->{layout} = 'ajax';

    $mech->submit_form(
        fields => $fields,
    );

    like($mech->status, qr/^4\d\d$/, 'verify error http response code');
    ok($mech->content_type eq 'application/json', 'verify that we get a json response');

    my $error = decode_json($mech->content);
    ok($error->{error} eq $expected_error, 'verify error id');

    $mech->get( 'http://localhost/mailbox/Sent?length=99999' );
    $mech->content_lacks("compose-message-test-$unix_time", 'verify that the message did not get place into the sent folder');

    $mech->get( 'http://localhost/mailbox/INBOX' );
    $mech->content_lacks("compose-message-test-$unix_time", 'verify that the message did not get sent');
}

done_testing();
