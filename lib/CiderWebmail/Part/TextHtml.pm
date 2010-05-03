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

    my $cleaner = HTML::Cleaner->new();

    my $cid_uris = {};
    while (my ($cid, $part_path) = each(%{ $self->parent_message->cid_to_part })) {
        $cid_uris->{$cid} = $self->c->uri_for("/mailbox/".$self->mailbox."/".$self->uid."/attachment/".$part_path);
    }

    #TODO ugly hack... HTML Cleaner should never have to know about mime content ids etc
    my $output = $cleaner->process({ input => $self->body, mime_cids => $cid_uris });
    return $self->c->view->render_template({ c => $self->c, template => 'TextHtml.xml', stash => { part_content => $output } });
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
