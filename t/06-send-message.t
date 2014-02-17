use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);


$mech->get_ok('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

my $to_address = $ENV{TEST_MAILADDR};
my $cc_address = $ENV{TEST_MAILADDR};

$cc_address =~ s/\@/+cc\@/;

my $sent_folder = find_special_folder('sent'),();

$mech->submit_form(
    with_fields => {
        from        => $ENV{TEST_MAILADDR},
        to          => $ENV{TEST_MAILADDR},
        cc          => $cc_address,
        sent_folder => $sent_folder,
        subject     => 'send-message-test-'.$unix_time,
        body        => 'send-message-body-'.$unix_time,
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );
my (@inbox_messages) = $mech->find_all_links( text_regex => qr{\Asend-message-test-$unix_time\z});
is(scalar @inbox_messages, 2, 'messages found');
$mech->get_ok($inbox_messages[0]->url, 'open message');
$mech->content_like(qr/send-message-body-$unix_time/, 'verify inbox message body content') || abort_testing();
xpath_test(sub {
    my ($tx) = @_;

    #MTA may append other domain names
    my ($to_test_address) = $to_address =~ m/(.*@).*$/;
    my ($cc_test_address) = $cc_address =~ m/(.*@).*$/;
    $cc_test_address =~ s/\+/\\+/;

    $tx->like('//tr[th="To:"]/td/span/a/@title', qr/^$to_test_address/);
    $tx->like('//tr[th="Cc:"]/td/span/a/@title', qr/^$cc_test_address/);
});

$mech->follow_link_ok({ url_regex => qr{/mailbox/?.*/$sent_folder} }, 'Open sent folder');
my (@sent_messages) = $mech->find_all_links( text_regex => qr{\Asend-message-test-$unix_time\z});
is(scalar @sent_messages, 1, 'messages found');
$mech->get_ok($sent_messages[0]->url, 'open message');
$mech->content_like(qr/send-message-body-$unix_time/, 'verify sent message body content') || abort_testing();

cleanup_messages(["send-message-test-$unix_time"]);

sub abort_testing {
    print STDERR "Unable to verify that your mailsystem can deliver messages to $ENV{TEST_MAILADDR}\n";
    print STDERR "Please ensure that the following environment variables are set correctly:\n\n";
    print STDERR "TEST_MAILADDR - e-Mail where testmessages are sent to\n";
    print STDERR "TEST_USER     - username of the IMAP account where TEST_MAILADDR delivers to\n";
    print STDERR "TEST_PASSWORD - password of the IMAP account\n\n";

    BAIL_OUT("Unable to test without a valid IMAP account");

}

done_testing();
