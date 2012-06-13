package CiderWebmail::Part::MultipartGeneric;

use Moose;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 0 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'x-ciderwebmail/multipart-generic'; }

sub load_children {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodystructure};

    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        push(@{ $self->parent_message->{children} }, $part) if $part;
        $self->root_message->part_id_to_part->{$part->part_id} = $part;
    }

    return;
}

1;
