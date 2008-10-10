package CiderWebmail::Controller::Mailbox;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

CiderWebmail::Controller::Mailbox - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched CiderWebmail::Controller::Mailbox in Mailbox.');
}

sub view : Local {
    my ( $self, $c, $mailbox ) = @_;
    $c->stash( template => 'mailbox.xml' );

    $c->model->select($c, { mailbox => "INBOX" } );

    $c->stash( folders  => [ map +{ name => $_, uri_view => $c->uri_for("/mailbox/view/$_") }, @{ $c->model->folders($c) } ] );
    $c->stash( messages => [ map +{ %{ $_->get_headers }, uri_view => $c->uri_for("/message/view/$_->{mailbox}/$_->{uid}") }, @{ $c->model->list_messages($c,{ mailbox => $mailbox}) } ] );
}



=head1 AUTHOR

Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
