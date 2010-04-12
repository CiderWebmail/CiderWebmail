package CiderWebmail::Part::MultipartAlternative;

use Moose;

has chosen_alternative => (is => 'rw', isa => 'Object');

extends 'CiderWebmail::Part';

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

sub render {
    my ($self) = @_;

    $self->chosen_alternative->render;
}

sub is_html {
    return 1;
}

sub renderable {
    return 1;
}

1;
