package CiderWebmail::Test;

use strict;
use warnings;
use Test::More;
use Exporter;
use base qw(Exporter);

our ($mech);
our @EXPORT = qw($mech xpath_test cleanup_messages);
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
    __PACKAGE__->export_to_level(1, $self, qw($mech xpath_test cleanup_messages));

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

sub cleanup_messages {
    my ($messages) = @_;

    foreach(@$messages) {
        my $message_subject = $_;

        $mech->get_ok( 'http://localhost/mailbox/INBOX?filter=' . $_, "fetch INBOS with filter for cleanup");
        my @messages_inbox = $mech->find_all_links( text_regex => qr{\A$_\z});
        foreach(@messages_inbox) {
            $mech->get_ok($_->url.'/delete', "cleanup message from INBOX");
            ok(@{$mech->find_all_links( text_regex => qr{\A$_\z})} == 0, 'message is gone from INBOX folder');
        }

        $mech->get_ok( 'http://localhost/mailbox/Sent?filter=' . $_, "fetch sent with filter for cleanup");
        my @messages_sent = $mech->find_all_links( text_regex => qr{\A$_\z});
        foreach(@messages_sent) {
            $mech->get_ok($_->url.'/delete', "cleanup message from Sent");
            ok(@{$mech->find_all_links( text_regex => qr{\A$_\z})} == 0, 'message is gone from Sent folder');
        }
        
        $mech->get_ok( 'http://localhost/mailbox/Trash?filter=' . $_, "fetch Trash folder with filter for cleanup");
        my @messages_trash = $mech->find_all_links( text_regex => qr{\A$_\z});
        foreach(@messages_trash) {
            $mech->get_ok($_->url.'/delete', "cleanup message from Trash");
            ok(@{$mech->find_all_links( text_regex => qr{\A$_\z})} == 0, 'message is gone from Trash folder');
        }

    }
}
