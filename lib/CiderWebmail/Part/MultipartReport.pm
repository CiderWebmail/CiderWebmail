package CiderWebmail::Part::MultipartReport;

use Moose;

extends 'CiderWebmail::Part::MultipartGeneric';

sub supported_type { return 'multipart/report'; }

1;
