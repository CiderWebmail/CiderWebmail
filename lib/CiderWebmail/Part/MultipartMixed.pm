package CiderWebmail::Part::MultipartMixed;

use Moose;

extends 'CiderWebmail::Part';

sub supported_type { return 'multipart/mixed'; }
sub renderable        { 0; }
sub attachment        { 0; }
sub render_by_default { 0; }

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
