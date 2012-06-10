use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);

my $uname = getpwuid $UID;

$mech->get_ok('http://localhost/mailboxes');

if($mech->content =~ m/<span class="name">Sent<\/span>/) {
    done_testing();
    exit;
} else {
    $mech->get_ok('http://localhost/create_folder');

    $mech->submit_form_ok({
        with_fields => {
            name => 'Sent',
        },
    });

}

$mech->get_ok('http://localhost/mailboxes');
$mech->content_contains('<span class="name">Sent</span>', 'verify new sent folder') or die "\n\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nYOU DO NOT HAVE A SEND FOLDER, AND THIS TEST WAS UNABLE TO CREATE IT. OTHER TESTS WILL FAIL BECAUSE OF THIS\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n\n";

done_testing();
