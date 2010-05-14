package CiderWebmail::Part::RFC822;

use Moose;
use CiderWebmail::Message::Forwarded;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';

=head2 render()

renders a message/rfc822 body part.

=cut

sub render {
    my ($self) = @_;

    croak('no entity set') unless defined $self->entity;

    return CiderWebmail::Message::Forwarded->new(c => $self->c, entity => $self->entity->parts(0), mailbox => $self->mailbox, uid => $self->uid, path => $self->path);
}

=head2 content_type()

returns the cntent type this plugin can handle

=cut

sub content_type {
    return 'message/rfc822';
}

=head2 message()

returns true if the part is a message (message/rfc822)

=cut

sub message {
    return 1;
}

=head2 attachment()

return false even if Content-Disposition is set to attachment.

=cut

sub attachment {
    return 0;
}

1;
