use strict;
use warnings;
use Test::More;
use Regexp::Common qw(Email::Address);
use Email::Address;

return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};

eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit;
}

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost/' );

$mech->submit_form_ok({
    with_fields => {
        username => $ENV{TEST_USER},
        password => $ENV{TEST_PASSWORD}
    }
});

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
