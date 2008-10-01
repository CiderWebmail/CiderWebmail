package CiderWebmail::Model::IMAPClient;

use strict;
use warnings;
use parent 'Catalyst::Model';

use Mail::IMAPClient;

=head1 NAME

CiderWebmail::Model::IMAPClient - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

sub login {
    my ($self, $c, $username, $password) = @_;

    my $imap = Mail::IMAPClient->new(
        Server => $c->config->{server}{host},
        User    => $username,
        Password=> $password,
    ) or die "Cannot connect: $@";

    $c->stash({imap => $imap});
}

sub folders {
    my ($self, $c) = @_;
    return $c->stash->{imap}->folders;
}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
