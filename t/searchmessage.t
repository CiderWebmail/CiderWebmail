use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);
use charnames ':full';

my $uname = getpwuid $UID;

$mech->follow_link_ok({ url_regex => qr{/compose} }, 'Compose a new message');

my $unix_time = time();

$mech->submit_form_ok({
    with_fields => {
        from        => "$uname\@localhost",
        to          => "$uname\@localhost",
        sent_folder => 'Sent',
        subject     => "searchmessage-utf8-\N{CHECK MARK}-$unix_time",
        body        => "searchmessage-utf8-\N{CHECK MARK}-body-$unix_time",
    },
});

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999' );
my @messages = $mech->find_all_links( text_regex => qr{\Asearchmessage-utf8-\N{CHECK MARK}-$unix_time\z});
$messages[0]->attrs->{id} =~ m/link_(\d+)/m;
my $message_id = $1;
ok( (length($message_id) > 0), 'got message id');

$mech->get_ok( 'http://localhost/mailbox/INBOX?length=99999&filter=searchmessage-utf8-'."\N{CHECK MARK}-$unix_time", 'search request successful' );

xpath_test {
    my ($tx) = @_;
    $tx->is("//a[\@id='link_$message_id']", "searchmessage-utf8-\N{CHECK MARK}-$unix_time", "correct message found" );
};

cleanup_messages(["searchmessage-utf8-\N{CHECK MARK}-$unix_time"]);

done_testing();
