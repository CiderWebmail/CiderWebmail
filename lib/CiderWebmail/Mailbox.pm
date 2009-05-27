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
    my ($self, $o) = @_;
    
    if (defined($o->{uids})) {
        return $self->{c}->model->get_headers_hash($self->{c}, { mailbox => $self->{mailbox}, uids => $o->{uids}, headers => [qw/From Subject Date/] });
    } else {
        return $self->{c}->model->get_headers_hash($self->{c}, { mailbox => $self->{mailbox}, sort => $o->{sort}, headers => [qw/From Subject Date/] });
    }
}

sub uids {
    my ($self, $o) = @_;

    return $self->{c}->model->get_folder_uids($self->{c}, { mailbox => $self->{mailbox}, sort => $o->{sort} });
}

sub simple_search {
    my ($self, $o) = @_;
   
    $o->{searchfor} = "ALL" unless $o->{searchfor};

    my $search_result = $self->{c}->model->simple_search($self->{c}, { mailbox => $self->{mailbox}, searchfor => $o->{searchfor} });
    $self->{uids} = $search_result;
}


1;
