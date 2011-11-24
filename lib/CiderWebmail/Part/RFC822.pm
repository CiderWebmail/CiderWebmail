package CiderWebmail::Part::RFC822;

use Moose;

use Carp qw/ croak /;
use CiderWebmail::Header;
use CiderWebmail::Message::Forwarded;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 1 );
has attachment          => (is => 'rw', isa => 'Bool', default => 0 );

has message_forwarded => ( isa => 'Object', is => 'rw' );

sub type {
    return 'message/rfc822';
}

=head2 render()

renders a message/rfc822 body part.

=cut

sub render {
    my ($self) = @_;

    return $self->c->view->render_template({ c => $self->c, template => 'RFC822.xml', stash => { message => $self } });
}

sub subject {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'subject', data => $self->bodystruct->envelopestruct->subject });
}

sub date {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'date', data => $self->bodystruct->envelopestruct->date });
}

sub from {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'from', data => join(', ', $self->bodystruct->envelopestruct->from_addresses) });
}

sub to {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'to', data => join(', ', $self->bodystruct->envelopestruct->to_addresses) });
}

sub cc {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'cc', data => join(', ', $self->bodystruct->envelopestruct->cc_addresses) });
}

sub bcc {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'bcc', data => join(', ', $self->bodystruct->envelopestruct->bcc_addresses) });
}

sub reply_to {
    my ($self) = @_;

    return CiderWebmail::Header::transform({ type => 'replyto', data => join(', ', $self->bodystruct->envelopestruct->bcc_addresses) });
}

sub mark_answered { 1; }

before qw(message_id references) => sub {
    my ($self) = @_;

    $self->message_forwarded(CiderWebmail::Message::Forwarded->new({ message_string => $self->body }));
};

sub message_id {
    my ($self) = @_;

    return $self->message_forwarded->get_header('Message-ID');
}

sub references {
    my ($self) = @_;

    return $self->message_forwarded->get_header('References');
}



=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'message/rfc822';
}

1;
