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

=head2 content_type()

returns the cntent type this plugin can handle

=cut

sub content_type {
    return 'text/plain';
}

=head2 renderable()

returns true if this part is renderable

=cut

sub renderable {
    return 1;
}

1;
