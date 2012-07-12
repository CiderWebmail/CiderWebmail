package CiderWebmail::Part::MultipartAlternative;

use Moose;
use List::Util qw(first);

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'multipart/alternative'; }

sub render {
    my ($self) = @_;

    return (    $self->preferred_alternative->render_as_stub ? 
                $self->preferred_alternative->render_stub : 
                $self->preferred_alternative->render );
}

sub preferred_alternative {
    my ($self) = @_;

    return (
        first { $_->render if $_->renderable } reverse @{ $self->children }
        or CiderWebmail::Part::Dummy->new({ root_message => $self->root_message, parent_message => $self->get_parent_message })
    );
}

1;
