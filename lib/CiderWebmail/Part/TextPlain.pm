package CiderWebmail::Part::TextPlain;

use Moose;
use Petal;

use Regexp::Common qw /URI/;
use HTML::Entities;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';

=head2 render()

Internal method rendering a text/plain body part.

=cut

sub render {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    my $content = $self->body;
    $content =~ s/$RE{URI}{-keep}/<a href="$1">$1<\/a>/xmg;

    HTML::Entities::encode_entities($content);
    
    return $self->c->view->render_template({ c => $self->c, template => 'TextPlain.xml', stash => { part_content => $content } });
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
    my ($self) = @_;
    return (($self->body or '') =~ /\S/xms);
}

1;
