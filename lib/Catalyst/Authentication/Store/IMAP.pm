package Catalyst::Authentication::Store::IMAP;

=head1 NAME

Catalyst::Authentication::Store::IMAP - Authentication store accessing an IMAP server.

=head1 SYNOPSIS

    use Catalyst qw(
      Authentication
      );

    __PACKAGE__->config(
      'authentication' => {
         default_realm => "imap",
         realms => {
           imap => {
             credential => {
               class          => "Password",
               password_field => "password",
               password_type  => "self_check",
             },
             store => {
               class => 'IMAP',
               host  => 'localhost',
             },
           },
         },
       },
    );

    sub login : Global {
        my ( $self, $c ) = @_;

        $c->authenticate({
                          id          => $c->req->param("login"), 
                          password    => $c->req->param("password") 
                         });
        $c->res->body("Welcome " . $c->user->username . "!");
    }

=head1 DESCRIPTION

This plugin implements the L<Catalyst::Authentication> v.10 API. Read that documentation first if
you are upgrading from a previous version of this plugin.

This plugin uses C<Mail::IMAPClient> to let your application authenticate against an IMAP server.
The used imap client object is stored on the stash as imapclient for use in other components.

=head1 CONFIGURATION OPTIONS

=head2 host

Sets the host name (or IP address) of the IMAP server.

=head2 port

Optionally set the port to connect to, defaults to 143.
If you specify port 993, L<IO::Socket::SSL> will be used for connecting.

=cut

use Moose;
use Catalyst::Authentication::Store::IMAP::User;

=head1 ATTRIBUTES

=head2 host

The host name used to connect to.

=cut

has host => (is => 'ro');

=head1 METHODS

=head2 new

=cut

sub new {
    my ($class, $config, $app, $realm) = @_;
    return $class->SUPER::new(host => $config->{host});
}

=head2 from_session

=cut

sub from_session {
    my ( $self, $c, $id ) = @_;

    return $id if ref $id;

    return $self->find_user( { id => $id } );
}

=head2 find_user

=cut

sub find_user {
    my ( $self, $userinfo, $c ) = @_;

    $userinfo->{c} = $c;
    $userinfo->{id} ||= $userinfo->{username};

    return Catalyst::Authentication::Store::IMAP::User->new($userinfo);
}

1;

=head1 SEE ALSO

L<Catalyst::Authentication::Store::IMAP::User>
L<Catalyst::Plugin::Authentication>, 
L<Mail::IMAPClient>

=head1 AUTHORS

Stefan Seifert <nine@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
