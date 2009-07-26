package CiderWebmail::Message::Forwarded;

use warnings;
use strict;

use base qw(CiderWebmail::Message);

sub new {
    my ($class, $c, $o) = @_;

    my $message = $class->SUPER::new($c, $o);
    $message->{entity} = $o->{entity};
    $message->{path}   = $o->{path};

    bless $message, $class;
}

sub get_header {
    my ($self, $header) = @_;

    return $self->{c}->model('IMAPClient')->transform_header($self->{c}, { header => $header, data => scalar $self->{entity}->head->get($header) });
}

sub header_formatted {
    my ($self) = @_;

    return $self->{entity}->head->as_string;
}

sub mark_read {
    # no use in marking an embedded message
    return;
}

sub delete {
    # no use in deleting an embedded message
    return;
}

sub move {
    # no use in deleting an embedded message
    return;
}

sub as_string {
    my ($self) = @_;

    return $self->{entity}->as_string;
}

1;
