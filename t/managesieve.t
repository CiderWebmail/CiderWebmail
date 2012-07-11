use strict;
use warnings;
use Test::More;
use CiderWebmail::Test {login => 1};
use English qw(-no_match_vars);

use charnames ':full';

if ( not $ENV{TEST_MANAGESIEVE} ) {
    my $msg = 'Managesieve test. Make sure you have a working managesieve server and set $ENV{TEST_MANAGESIEVE} to a true value to run.';
    plan( skip_all => $msg );
}

my $unix_time = time();

#open script list
$mech->get_ok('http://localhost', 'open mailbox');
$mech->follow_link_ok({ url_regex => qr{/managesieve$} }, 'open managesieve list');
$mech->follow_link_ok({ url_regex => qr{/managesieve/edit$} }, 'open create new script dialog for new script');


#create a new script
$mech->form_with_fields(qw/ sieve_script_name sieve_script_content /);
$mech->set_fields( 
        sieve_script_name       => "testscript-inactive-$unix_time",
        sieve_script_content    => 'require ["fileinto", "reject"];',
);
$mech->click_ok('sieve_script_save', 'create test script');


#open script list and verify that script exists and is inactive
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');
$mech->content_contains("testscript-inactive-$unix_time", 'verify that the new script exists');
xpath_test { my ($tx) = @_; $tx->is("//tr[\@script-name='testscript-inactive-$unix_time']/td[2]", 'inactive', 'check that script is inactive'); };


#rename and set script active and change content (swap reject/fileinto order)
$mech->follow_link_ok({ url_regex => qr{edit\?sieve_script_name=testscript-inactive-$unix_time} }, "open script edit dialog for testscript-inactive-$unix_time" );

#verify values in edit form (loaded from server) 
ok(($mech->field('sieve_script_content') eq 'require ["fileinto", "reject"];'."\n"), 'textarea sieve_script_content value');
ok(($mech->field('sieve_script_name') eq "testscript-inactive-$unix_time"), 'input sieve_script_name');
ok(($mech->field('sieve_script_original_name') eq "testscript-inactive-$unix_time"), 'input sieve_script_original_name');

$mech->form_with_fields(qw/ sieve_script_name sieve_script_content /);
$mech->set_fields( 
        sieve_script_original_name  => "testscript-inactive-$unix_time",
        sieve_script_name           => "testscript-active-$unix_time",
        sieve_script_content        => 'require ["reject", "fileinto"];',
        sieve_script_active         => 1,
);
$mech->click_ok('sieve_script_save', 'set test script active and rename');


#check that script is now active and renamed
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');
xpath_test { my ($tx) = @_; $tx->is("//tr[\@script-name='testscript-active-$unix_time']/td[2]", 'active', 'check that script now active and was correctly renamed'); };


#disable script
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');

$mech->follow_link_ok({ url_regex => qr{edit\?sieve_script_name=testscript-active-$unix_time} }, "open script edit dialog for testscript-active-$unix_time" );

#verify values in edit form (loaded from server) 
ok(($mech->field('sieve_script_content') eq 'require ["reject", "fileinto"];'."\n"), 'textarea sieve_script_content value');
ok(($mech->field('sieve_script_name') eq "testscript-active-$unix_time"), 'input sieve_script_name');
ok(($mech->field('sieve_script_original_name') eq "testscript-active-$unix_time"), 'input sieve_script_original_name');

$mech->set_fields( 
        sieve_script_original_name  => "testscript-active-$unix_time",
        sieve_script_name           => "testscript-inactive-$unix_time",
        sieve_script_content        => 'require ["reject", "fileinto"];',
        sieve_script_active         => undef,
);
$mech->click_ok('sieve_script_save', 'set test script back to inactive and rename');


#verify that test script is now inactive
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');
xpath_test { my ($tx) = @_; $tx->is("//tr[\@script-name='testscript-inactive-$unix_time']/td[2]", 'inactive', 'check that script now inactive and was correctly renamed'); };



##TODO UTF-8 in Managesieve is currently not working
##$mech->follow_link_ok({ url_regex => qr{edit/testscript-active-$unix_time} }, "open script edit dialog for testscript-active-$unix_time" );
##$mech->form_with_fields(qw/ script_name script_content /);
##$mech->set_fields(
##    script_name => "testscript-active-\N{CHECK MARK}-$unix_time",
##);
##$mech->click_ok('save_script', 'add utf8 testcharacter to script name');

#delete script
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');
$mech->follow_link_ok({ url_regex => qr{delete\?sieve_script_name=testscript-inactive-$unix_time} }, "delete script testscript-active-$unix_time" );
$mech->get_ok('http://localhost/managesieve/list', 'open managesieve list');
$mech->content_lacks("testscript-active-$unix_time", 'verify that the test script was deleted');


done_testing();
