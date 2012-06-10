package CiderWebmail::Part::MultipartSigned;

use Moose;

extends 'CiderWebmail::Part::MultipartGeneric';

sub supported_type { return 'multipart/signed'; }

1;
