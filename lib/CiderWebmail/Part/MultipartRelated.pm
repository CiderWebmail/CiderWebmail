package CiderWebmail::Part::MultipartRelated;

use Moose;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 0 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'multipart/related'; }

sub load_children {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodystructure};

    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        push(@{ $self->parent_message->{children} }, $part) if $part;
        $self->root_message->parts->{$part->id} = $part;
    }
}

1;
