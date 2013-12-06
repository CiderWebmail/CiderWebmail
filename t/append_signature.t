use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);


$mech->get_ok('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

$mech->submit_form(
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        sent_folder => 'Sent',
        subject     => 'append_signature_subject-'.$unix_time,
        signature   => 'append_signature_signature-'.$unix_time,
        body        => 'append_signature_body-'.$unix_time,
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );
my (@inbox_messages) = $mech->find_all_links( text_regex => qr{\Aappend_signature_subject-$unix_time\z});
ok((@inbox_messages == 1), 'messages found');
$mech->get_ok($inbox_messages[0]->url, 'open message');
$mech->content_like(qr/append_signature_body-$unix_time/, 'verify inbox message body content');
$mech->content_like(qr/\-\-\s<br \/>append_signature_signature-$unix_time/, 'verify sent message signature');

$mech->get( 'http://localhost/mailbox/Sent?length=99999' );
my (@sent_messages) = $mech->find_all_links( text_regex => qr{\Aappend_signature_subject-$unix_time\z});
ok((@sent_messages == 1), 'messages found');
$mech->get_ok($sent_messages[0]->url, 'open message');
$mech->content_like(qr/append_signature_body-$unix_time/, 'verify inbox message body content');
$mech->content_like(qr/\-\-\s<br \/>append_signature_signature-$unix_time/, 'verify sent message signature');

$mech->get_ok('http://localhost/mailbox/INBOX/compose');
xpath_test {
    my ($tx) = @_;
    $tx->is("//textarea[\@id='signature']", 'append_signature_signature-'.$unix_time, "signature saved in database" );
};

cleanup_messages(["append_signature_subject-$unix_time"]);

done_testing();
