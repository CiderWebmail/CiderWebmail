package Catalyst::Authentication::Store::IMAP;

use base qw/Class::Accessor::Fast/;

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
    my $id = $userinfo->{id} || $userinfo->{username};

    my $imap = Mail::IMAPClient->new(
        Server => $c->config->{server}{host},
        User    => $id,
        Password=> $password,
    ) or die "Cannot connect: $@";

    $c->stash({imap => $imap});
}

1;
