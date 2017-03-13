use strict;
use warnings;
use FindBin qw($Bin);

use lib "$Bin/lib";
use CiderWebmail;
use Plack::Builder;

builder {
        enable( "Plack::Middleware::ReverseProxyPath" );
	my $app = Atikon::Intranet->apply_default_middlewares(CiderWebmail->psgi_app);
        $app;
}
