package CiderWebmail::Part::TextHtml;

use Moose;

use HTML::Cleaner;

extends 'CiderWebmail::Part';

=head2 render()

renders a text/html body part.

=cut

sub render {
    my ($self) = @_;

    die 'no part set' unless defined $self->body;

    my $cleaner = HTML::Cleaner->new({ input => $self->body });

    return $self->c->view->render_template({ c => $self->c, template => 'TextHtml.xml', stash => { part_content => $cleaner->process } });
}

=head2 content_type()

returns the cntent type this plugin can handle

=cut

sub content_type {
    return 'text/html';
}

=head2 renderable()

returns true if this part is renderable

=cut

sub renderable {
    return 1;
}

1;
