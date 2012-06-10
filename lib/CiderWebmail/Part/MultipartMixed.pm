package CiderWebmail::Part::MultipartMixed;

use Moose;

extends 'CiderWebmail::Part::MultipartGeneric';

sub supported_type { return 'multipart/mixed'; }

1;
