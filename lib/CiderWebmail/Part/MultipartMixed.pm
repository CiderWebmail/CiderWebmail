package CiderWebmail::Part::MultipartMixed;

use Moose;

extends 'CiderWebmail::Part';

sub content_type {
    return 'multipart/mixed';
}

1;
