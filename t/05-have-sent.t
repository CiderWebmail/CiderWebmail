use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);

$mech->get_ok('http://localhost/mailboxes');

my $sent_folder = find_special_folder('sent');

if(defined $sent_folder) {
    like($sent_folder, qr/Sent/, "Found Sent folder '$sent_folder'");
    done_testing();
    exit;
} else {
    $mech->get_ok('http://localhost/mailboxes');

    #this is not perfect but works with default dovecot&courier installations until we finish support for special use mailboxes
    $mech->follow_link_ok({ url_regex => qr{INBOX/create_subfolder} }, 'Follow create subfolder link');

    $mech->submit_form_ok({
        with_fields => {
            name => 'Sent',
        },
    });

    $mech->get_ok('http://localhost/mailboxes');
    $sent_folder = find_special_folder('sent');
    like($sent_folder, qr/Sent/, "Verified new Sent folder '$sent_folder'");
}


done_testing();
