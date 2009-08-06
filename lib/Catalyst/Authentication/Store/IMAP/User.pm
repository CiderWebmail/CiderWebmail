package Catalyst::Authentication::Store::IMAP::User;

=head1 NAME

Catalyst::Authentication::Store::IMAP::User - An authentication user for IMAP.

=head1 SYNOPSIS

	use Catalyst::Authentication::Store::IMAP::User;
	
	Catalyst::Authentication::Store::IMAP::User->new(
		id => "username",
	);

=head1 DESCRIPTION

This implementation of authentication user handles is supposed to go hand in
hand with L<Catalyst::Authentication::Store::IMAP>.

=cut

use Moose;
use Mail::IMAPClient;

extends qw/Catalyst::Authentication::User/;

has id => (is => 'ro', isa => 'Str');

=head1 METHODS

=head2 new( @pairs )

Create a new object with the key-value-pairs listed in the arg list.

=head2 supports( )

Checks for existence of keys that correspond with features.

=cut

sub supported_features {
    return {
        roles => 1,
    };
}

=head2 for_session( )

Just returns $self, expecting it to be serializable.

=cut

sub for_session {
    my $self = shift;
    
    return $self; # we serialize the whole user
}

=head2 from_session( )

Just passes returns the unserialized object, hoping it's intact.

=cut

sub from_session {
    my ( $self, $c, $user ) = @_;

    return $user;
}

=head2 store( )

Accessors that override superclass's dying virtual methods.

=cut

=head2 id( )

=cut

=head2 check_password( $password )

Establishes a connection to the IMAP server and checks the given user credentials.
Stores the Mail::IMAPClient object on the stash as imapclient for usage by other components.

=cut

sub check_password {
    my ($self, $password) = @_;

    my $id = $self->id;
    my $c  = $self->{c};

    my %connect_info = (
        Server  => $c->config->{authentication}{realms}{imap}{store}{host},
    );

    if (exists $c->config->{server}{port}) {
        $connect_info{Port} = $c->config->{server}{port};
        if ($connect_info{Port} == 993) { # use SSL
            require IO::Socket::SSL;
            my $ssl = new IO::Socket::SSL("$connect_info{Server}:imaps");
            die ("Error connecting to IMAP server: $@") unless defined $ssl;
            $ssl->autoflush(1);
            %connect_info = (Socket => $ssl);
        }
    }

    my $imap = Mail::IMAPClient->new(
        %connect_info,
        Peek => 1,
    ) or die "Error connecting to IMAP server: $@";

    $imap->User($id);
    $imap->Password($password);

    unless($imap->login) {
        warn "Could not login to ".$c->config->{authentication}{realms}{imap}{store}{host}." with user $id: $@";
        return;
    }

    $c->stash({imapclient => $imap});
    return 1;
}

1;

=head1 SEE ALSO

L<Hash::AsObject>

=cut

=head1 AUTHOR

Stefan Seifert <nine@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

