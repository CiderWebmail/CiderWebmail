package CiderWebmail::Part::MultipartGeneric;

use Moose;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 0 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'x-ciderwebmail/multipart-generic'; }

sub load_children {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodystructure};

    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        push(@{ $self->parent_message->{children} }, $part) if $part;
        $self->root_message->parts->{$part->id} = $part;
    }

    return;
}

1;
