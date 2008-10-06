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
    my $model = $c->model();

    $c->stash( template => 'mailbox.xml' );

    #TODO maybe move this to some 'global' part - we will need it nearly everywhere
    #TODI per-server/per-user INBOX name/seperator/namespace/...
    $c->model->select($c, "INBOX");
    $c->stash( folders => [ $model->folders($c) ] );

    $c->stash( messages => $c->model->messages($c, $mailbox) );
}



=head1 AUTHOR

,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
