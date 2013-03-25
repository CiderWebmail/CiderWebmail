use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;
use English qw(-no_match_vars);

my $uname = getpwuid $UID;

$mech->get_ok('http://localhost/mailbox/INBOX/compose');

my $unix_time = time();

$mech->submit_form(
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        cc          => "$uname+cc\@localhost",
        sent_folder => 'Sent',
        subject     => 'send-message-test-'.$unix_time,
        body        => 'send-message-body-'.$unix_time,
    },
);

$mech->get( 'http://localhost/mailbox/INBOX?length=99999' );
my (@inbox_messages) = $mech->find_all_links( text_regex => qr{\Asend-message-test-$unix_time\z});
is(scalar @inbox_messages, 1, 'messages found');
$mech->get_ok($inbox_messages[0]->url, 'open message');
$mech->content_like(qr/send-message-body-$unix_time/, 'verify inbox message body content') || die "\n\nXXXXXXXXXXXXXXXXXXXXX\n\nYOUR MAILSYSTEM IS UNABLE TO DELIVER MAIL TO $uname\@localhost THIS WILL BREAK LATER TESTS - VERIFY INBOX FOLDER FAILED\n\nXXXXXXXXXXXXXXXXXXY\n\n";
xpath_test(sub {
    my ($tx) = @_;
    $tx->like('//tr[th="To:"]/td/span/a/text()', qr/$uname\@localhost/);
    $tx->like('//tr[th="Cc:"]/td/span/a/text()', qr/$uname\+cc\@localhost/);
});

$mech->get( 'http://localhost/mailbox/Sent?length=99999' );
my (@sent_messages) = $mech->find_all_links( text_regex => qr{\Asend-message-test-$unix_time\z});
is(scalar @sent_messages, 1, 'messages found');
$mech->get_ok($sent_messages[0]->url, 'open message');
$mech->content_like(qr/send-message-body-$unix_time/, 'verify sent message body content') || die "\n\nXXXXXXXXXXXXXXXXXXXXX\n\nYOUR MAILSYSTEM IS UNABLE TO DELIVER MAIL TO $uname\@localhost THIS WILL BREAK LATER TESTS - VERIFY SENT FOLDER FAILED\n\nXXXXXXXXXXXXXXXXXXY\n\n";

cleanup_messages(["send-message-test-$unix_time"]);

done_testing();
