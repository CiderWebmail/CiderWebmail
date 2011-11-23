package CiderWebmail::Part::MultipartMixed;

use Moose;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 0 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

sub supported_type { return 'multipart/mixed'; }

sub load_children {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodystructure};

    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        #warn "Part ".$part->id." (parent: ".$self->parent_message->id.") loaded with ".$part->content_type." is ".( $part->attachment ? "attachment" : "" ) ." ".($part->renderable ? "renderable" : "") . " " . ($part->render_by_default ? "render_by_default" : "" );;
        push(@{ $self->parent_message->{children} }, $part) if $part;
        $self->root_message->parts->{$part->id} = $part;
    }
}

1;
