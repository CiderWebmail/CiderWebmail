package CiderWebmail::Part::MultipartAlternative;

use Moose;

has chosen_alternative => (is => 'rw', isa => 'Object');

extends 'CiderWebmail::Part';

=head2 content_type()

returns the content type the CiderWebmail::Part Plugin can handle (just a stub, override in CiderWebmail::Part::FooBar)

=cut

sub content_type {
    return 'multipart/alternative';
}

before render => sub {
    my ($self) = @_;

    my @parts = reverse($self->subparts);

    foreach(@parts) {
        my $part = CiderWebmail::Part->new({ c => $self->c, entity => $_, uid => $self->uid, mailbox => $self->mailbox, path => defined $self->path, id => 0 })->handler;
        if ($part->renderable) {
            $self->chosen_alternative($part);
            last;
        }
    }

};

=head2 render()

render a multipart/alternative

=cut

sub render {
    my ($self) = @_;

    return $self->chosen_alternative->render;
}

=head2 renderable()

returns true if the part is renderable.

=cut

sub renderable {
    return 1;
}

1;
