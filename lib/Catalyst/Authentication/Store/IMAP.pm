package Catalyst::Authentication::Store::IMAP;

use base qw/Class::Accessor::Fast/;
use Catalyst::Authentication::Store::IMAP::User;

BEGIN {
    __PACKAGE__->mk_accessors(qw/host/);
}

sub new {
    my ($class, $config, $app, $realm) = @_;
    my $self = {host => $config->{host}};
    return bless $self, $class;
}

sub from_session {
    my ( $self, $c, $id ) = @_;

    return $id if ref $id;

    $self->find_user( { id => $id } );
}

sub find_user {
    my ( $self, $userinfo, $c ) = @_;

    $userinfo->{c} = $c;
    $userinfo->{id} ||= $userinfo->{username};
    return Catalyst::Authentication::Store::IMAP::User->new($userinfo);
}

1;
