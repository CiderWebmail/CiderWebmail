package CiderWebmail::Part::ImageJpeg;

use Moose;
use Petal;

use Regexp::Common qw /URI/;
use HTML::Entities;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

=head2 render()

Internal method rendering a image body part.

=cut

sub render {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    return $self->c->view->render_template({ c => $self->c, template => 'Image.xml', stash => { part => $self } });
}

sub render_stub {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    return $self->c->view->render_template({ c => $self->c, template => 'Stub.xml', stash => { part => $self } });
}

=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'image/jpeg';
}

1;
