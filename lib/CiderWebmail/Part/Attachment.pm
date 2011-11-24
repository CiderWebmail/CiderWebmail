package CiderWebmail::Part::Attachment;

use Moose;
use Petal;

use Regexp::Common qw /URI/;
use HTML::Entities;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 0 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );
has attachment          => (is => 'rw', isa => 'Bool', default => 1 );

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

1;
