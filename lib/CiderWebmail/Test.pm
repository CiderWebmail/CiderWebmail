package CiderWebmail::Test;

use strict;
use warnings;
use Test::More;
use Exporter;
use base qw(Exporter);

our ($mech);
our @EXPORT = qw($mech xpath_test);
sub import {
    my ($self, $params) = @_;

    $params ||= {};
    if ($params->{test_user} or $params->{login}) {
        return plan skip_all => 'Set TEST_USER and TEST_PASSWORD to access a mailbox for these tests' unless $ENV{TEST_USER} and $ENV{TEST_PASSWORD};
    }

    eval "use Test::WWW::Mechanize::Catalyst 'CiderWebmail'";
    if ($@) {
        return plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    }

    $mech = Test::WWW::Mechanize::Catalyst->new;
    __PACKAGE__->export_to_level(1, $self, qw($mech xpath_test));

    if ($params->{login}) {
        $mech->get( 'http://localhost/' );
        $mech->submit_form(with_fields => { username => $ENV{TEST_USER}, password => $ENV{TEST_PASSWORD} });
    }
}

sub xpath_test(&) {
    my ($sub) = @_;

    SKIP: {
        eval { require Test::XPath; };
        skip 'Test::XPath required for some tests', 1 if $@;

        my $tx = Test::XPath->new(xml => $mech->content, is_html => 1);

        $sub->($tx);
    }
}
