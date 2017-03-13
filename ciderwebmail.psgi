use strict;
use warnings;
use FindBin qw($Bin);

use lib "$Bin/lib";
use CiderWebmail;

my $app = CiderWebmail->apply_default_middlewares(CiderWebmail->psgi_app);
$app;
