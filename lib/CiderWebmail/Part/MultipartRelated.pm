package CiderWebmail::Part::MultipartRelated;

use Moose;

extends 'CiderWebmail::Part::MultipartGeneric';

sub supported_type { return 'multipart/related'; }

1;
