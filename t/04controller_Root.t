use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use Regexp::Common qw(Email::Address);
use Email::Address;

$mech->follow_link_ok({ url_regex => qr{/mailboxes\z} });

$mech->follow_link_ok({ url_regex => qr{/create_folder\z} });

$mech->submit_form_ok({
    with_fields => {
        name => 'Testfolder',
    },
});

$mech->follow_link_ok({ url_regex => qr{/Testfolder/create_subfolder\z} });

$mech->submit_form_ok({
    with_fields => {
        name => 'Testsubfolder',
    },
});

$mech->follow_link_ok({ url_regex => qr{Testfolder/delete\z} });

$mech->follow_link_ok({ url_regex => qr{/logout\z} });

done_testing();
