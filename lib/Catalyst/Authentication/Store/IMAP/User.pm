package Catalyst::Authentication::Store::IMAP::User;

use strict;
use warnings;

use base qw/Catalyst::Authentication::User/;

sub new {
    my $class = shift;

    bless { ( @_ > 1 ) ? @_ : %{ $_[0] } }, $class;
}

# this class effectively handles any method calls
sub can { 1 }

sub id {
    my $self = shift;
    $self->{id};
}

sub supported_features {
    return {
#        session => 1,
        roles   => 1,
    };
}

sub for_session {
    my $self = shift;
    
    return $self; # we serialize the whole user
}

sub from_session {
    my ( $self, $c, $user ) = @_;
    $user;
}

sub check_password {
    my ($self, $password) = @_;

    my $id = $self->id;
    my $c = $self->{c};

    my %connect_info = (
        Server  => $c->config->{authentication}{realms}{imap}{store}{host},
    );

    if (exists $c->config->{server}{port}) {
        $connect_info{Port} = $c->config->{server}{port};
        if ($connect_info{Port} == 993) { # use SSL
            require IO::Socket::SSL;
            my $ssl = new IO::Socket::SSL("$connect_info{Server}:imaps");
            die ("Error connecting - $@") unless defined $ssl;
            $ssl->autoflush(1);
            %connect_info = (Socket => $ssl);
        }
    }

    my $imap = Mail::IMAPClient->new(
        %connect_info,
        User => $id,
        Password => $password,
        Peek => 1,
    ) or return;

    $c->stash({imap => $imap});
    return 1;
}

1;

__END__

=pod

=head1 NAME

Catalyst::Authentication::User::Hash - An easy authentication user
object based on hashes.

=head1 SYNOPSIS

	use Catalyst::Authentication::User::Hash;
	
	Catalyst::Authentication::User::Hash->new(
		password => "s3cr3t",
	);

=head1 DESCRIPTION

This implementation of authentication user handles is supposed to go hand in
hand with L<Catalyst::Authentication::Store::Minimal>.

=head1 METHODS

=head2 new( @pairs )

Create a new object with the key-value-pairs listed in the arg list.

=head2 supports( )

Checks for existence of keys that correspond with features.

=head2 for_session( )

Just returns $self, expecting it to be serializable.

=head2 from_session( )

Just passes returns the unserialized object, hoping it's intact.

=head2 AUTOLOAD( )

Accessor for the key whose name is the method.

=head2 store( )

Accessors that override superclass's dying virtual methods.

=head2 id( )

=head2 can( )

=head1 SEE ALSO

L<Hash::AsObject>

=cut


