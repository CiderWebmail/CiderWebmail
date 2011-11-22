package CiderWebmail::Part::Dummy;

use Moose;
use Petal;

use Regexp::Common qw /URI/;
use HTML::Entities;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';

sub load_children { 1; }

=head2 render()

Internal method rendering a x-ciderwebmail/textdummy body part.

=cut

sub render {
    my ($self) = @_;

    return $self->c->view->render_template({ c => $self->c, template => 'TextPlain.xml', stash => { part_content => ' ' } });
}

sub body {
    my ($self) = @_;

    return ' ';
}

=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'x-ciderwebmail/textdummy';
}

sub renderable { 0; }
sub attachment { 0; }
sub render_by_default { 0; }


1;
