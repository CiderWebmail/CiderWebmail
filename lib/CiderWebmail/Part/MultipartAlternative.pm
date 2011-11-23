package CiderWebmail::Part::MultipartAlternative;

use Moose;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'multipart/alternative'; }

sub render {
    my ($self) = @_;

    foreach(reverse @{ $self->children }) {
        return $_->render if $_->renderable;
    }
}

1;
