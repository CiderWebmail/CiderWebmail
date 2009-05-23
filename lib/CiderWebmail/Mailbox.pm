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
    
    if (defined($self->{uids})) {
        return $c->model->get_headers_hash($c, { mailbox => $self->{mailbox}, uids => $self->{uids}, headers => [qw/From Subject Date/] });
    } else {
        return $c->model->get_headers_hash($c, { mailbox => $self->{mailbox}, sort => $o->{sort}, headers => [qw/From Subject Date/] });
    }
}

sub uids {
    my ($self, $c, $o) = @_;

    return $c->model->get_folder_uids($c, { mailbox => $self->{mailbox} });
}

sub simple_search {
    my ($self, $c, $o) = @_;
   
    die unless $o->{searchfor};

    my $search_result = $c->model->simple_search($c, { mailbox => $self->{mailbox}, searchfor => $o->{searchfor} });
    $self->{uids} = $search_result;
}


1;
