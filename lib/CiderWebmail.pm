package CiderWebmail;

use Moose;

use strict;
use warnings;

use Catalyst::Runtime '5.80';

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a YAML file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use Catalyst qw/
    ConfigLoader

    StackTrace

    Static::Simple
    Authentication
    Unicode

    Session
    Session::Store::FastMmap
    Session::State::Cookie
/;

our $VERSION = '1.04';

# Configure the application. 
#
# Note that settings in ciderwebmail.yml (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'CiderWebmail',
    authentication => {
        default_realm => 'imap',
        realms => {
            imap => {
                credential => {
                    class => 'Password',
                    password_type => 'self_check',
                    password_field =>  'password',
                },
                store => {
                    class => 'IMAP',
                    host => undef,
                },
            },
        },
    },
);

#don't display password in debugging output
around 'log_request_parameters' => sub {
    my $super = shift;
    my($c, %params) = @_;
    $params{body}{password} = 'XXX-password-removed-XXX';
    $c->$super(%params)
};

# Start the application
__PACKAGE__->setup;

__PACKAGE__->config->{authentication}{realms}{imap}{store}{host} ||= ($ENV{IMAPHOST} || __PACKAGE__->config->{server}{host});

=head1 NAME

CiderWebmail - Catalyst based application

=head1 SYNOPSIS

    script/ciderwebmail_server.pl

=head1 DESCRIPTION

CiderWebmail: webmail sucks - we suck less!

=head1 SEE ALSO

L<CiderWebmail::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
