package Catalyst::Plugin::CiderWebmail::ErrorHandler;

$Catalyst::Plugin::CiderWebmail::ErrorHandler::VERSION = '0.1';

use warnings;
use strict;

use Carp qw/ confess /;
use JSON::XS;

use Scalar::Util qw/ blessed /;

sub finalize_error {
    my $c = shift;
    
    #TODO handle >1 errors
    confess("ErrorHandler called without error") unless (defined $c->error->[0]);

    my $error = $c->error->[0];
    if (blessed $error and $error->DOES('CiderWebmail::Error')) {
        $c->response->status($error->code);

        if (($c->req->param('layout') or '') eq 'ajax') {
            my $json = encode_json {
                error   => $error->error,
                message => $error->message,
            };

            $c->response->content_type('application/json');
            $c->response->body($json);
        } else {
            $c->response->content_type('text/plain');
            $c->response->body($error->message);
            #TODO pretty error message
        }
    } else {
        $c->maybe::next::method;
    }
}

1;
