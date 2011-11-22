package CiderWebmail::Part::Attachment;

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

    return '';
}

=head2 supported_type ()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'x-ciderwebmail/attachment';
}

sub attachment { 1; }
sub renderable { 0; }
sub render_by_default { 0; }

1;
