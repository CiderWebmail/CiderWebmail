package CiderWebmail::Part::RFC822;

use Moose;
use CiderWebmail::Message::Forwarded;

extends 'CiderWebmail::Part';

sub render {
    my ($self) = @_;

    die 'no entity set' unless defined $self->entity;

    return CiderWebmail::Message::Forwarded->new(c => $self->c, entity => $self->entity->parts(0), mailbox => $self->mailbox, uid => $self->uid, path => $self->path);
}

sub content_type {
    return 'message/rfc822';
}

sub message {
    return 1;
}

1;
