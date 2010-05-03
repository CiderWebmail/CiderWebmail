package CiderWebmail::Part::MultipartRelated;

use Moose;

extends 'CiderWebmail::Part';

=head2 content_type()

returns the cntent type this plugin can handle

=cut

sub content_type {
    return 'multipart/related';
}

1;
