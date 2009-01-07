package CiderWebmail::Mailbox;

use warnings;
use strict;

use CiderWebmail::Message;
use Mail::Address;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};

    my $mailbox = {
        mailbox => $o->{mailbox},
        c => $c,
    };

    bless $mailbox, $class;
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

sub list_messages_hash {
    my ($self, $c, $o) = @_;
   
    return $c->model->get_headers_hash($c, { mailbox => $self->{mailbox}, headers => [qw/From Subject Date/] });
}

sub simple_search {
    my ($self, $c, $o) = @_;
   
    die unless $o->{searchfor};

    my $search_result = $c->model->simple_search($c, { mailbox => $self->{mailbox}, searchfor => $o->{searchfor} });

    my @messages = map +{
        uid     => $_,
        mailbox => $self->{mailbox},
        from    => scalar $c->model->get_headers($c, { mailbox => $self->{mailbox}, uid => $_, headers => [qw/From/] }),
        subject => scalar $c->model->get_headers($c, { mailbox => $self->{mailbox}, uid => $_, headers => [qw/Subject/] }),
        date    => $c->model->date($c, { mailbox => $self->{mailbox}, uid => $_, }),
    }, @$search_result;

    foreach(@messages) {
        my @address = Mail::Address->parse($_->{from});
        $_->{from} = $address[0];
    }


    return \@messages;
}


1;
