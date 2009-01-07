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

sub list_messages {
    my ($self, $c, $o) = @_;

    my $messages_header_hash = $c->model->fetch_headers_hash($c, { mailbox => $self->{mailbox} });
    my @messages = ();

    foreach my $message ( @$messages_header_hash ) {
        push(@messages, CiderWebmail::Message->new($self->{c},
            {
                mailbox => $message->{mailbox},
                uid     => $message->{uid},
                from    => $message->{from},
                to      => $message->{to},
                subject => $message->{subject},
                date    => $message->{date},
            }));
    }

    return \@messages;
}

sub list_messages_hash {
    my ($self, $c, $o) = @_;
   
    my $messages = $c->model->fetch_headers_hash($c, { mailbox => $self->{mailbox} });

    foreach(@$messages) {
        my @address = Mail::Address->parse($_->{from});
        $_->{from} = $address[0];
    }

    return $messages;
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
