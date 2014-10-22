package CiderWebmail::Test;

use strict;
use warnings;
use Test::More;
use Exporter;
use base qw(Exporter);

our ($mech);
our @EXPORT = qw($mech xpath_test cleanup_messages find_special_folder find_folder);
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
    __PACKAGE__->export_to_level(1, $self, qw($mech xpath_test cleanup_messages find_special_folder find_folder));

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

sub find_special_folder {
    my ($class) = @_;

    my $special_folder = '';

    xpath_test {
        my ($tx) = @_;
        $special_folder = $tx->find_value("//a[contains(\@class,'$class')]/\@title");
    };

    return length($special_folder) ? $special_folder : undef;
}

sub find_folder {
    my ($re) = @_;

    my $folder_name;

    xpath_test {
        my ($tx) = @_;
        my $folders = $tx->xpc->find("//a[contains(\@class, 'folder')]/\@title");

        foreach my $folder ($folders->get_nodelist) {
            if ($folder->value =~ $re) {
                 $folder_name = $folder->value();
            }
        }
    };

    return length($folder_name) ? $folder_name : undef;
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

        my $sent_folder = find_special_folder('sent');

        $mech->get_ok( 'http://localhost/mailbox/' . $sent_folder . '?filter=' . $_, "fetch sent with filter for cleanup");
        my @messages_sent = $mech->find_all_links( text_regex => qr{\A$_\z});
        foreach(@messages_sent) {
            $mech->get_ok($_->url.'/delete', "cleanup message from Sent");
            ok(@{$mech->find_all_links( text_regex => qr{\A$_\z})} == 0, 'message is gone from Sent folder');
        }

        my $trash_folder = find_special_folder('trash');

        if (defined $trash_folder) {
            $mech->get_ok( 'http://localhost/mailbox/' . $trash_folder . '?filter=' . $_, "fetch Trash folder with filter for cleanup");
            my @messages_trash = $mech->find_all_links( text_regex => qr{\A$_\z});
            foreach(@messages_trash) {
                $mech->get_ok($_->url.'/delete', "cleanup message from Trash");
                ok(@{$mech->find_all_links( text_regex => qr{\A$_\z})} == 0, 'message is gone from Trash folder');
            }
        }
    }
}
