package CiderWebmail::Part::TextPlain;

use Moose;
use Petal;

extends 'CiderWebmail::Part';

=head2 render()

Internal method rendering a text/plain body part.

=cut

sub render {
    my ($self) = @_;

    die 'no part set' unless defined $self->body;
    
    return $self->c->view->render_template({ c => $self->c, template => 'TextPlain.xml', stash => { part_content => Text::Flowed::reformat($self->body) } });
}

sub content_type {
    return 'text/plain';
}

sub is_text {
    return 1;
}

sub renderable {
    return 1;
}

1;
