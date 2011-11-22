package CiderWebmail::Part::MultipartAlternative;

use Moose;

extends 'CiderWebmail::Part';

sub supported_type { return 'multipart/alternative'; }
sub renderable        { 1; }
sub attachment        { 0; }
sub render_by_default { 1; }

sub render {
    my ($self) = @_;

    foreach(reverse @{ $self->children }) {
        return $_->render if $_->renderable;
    }
}

1;
