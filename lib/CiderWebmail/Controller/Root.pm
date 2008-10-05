package CiderWebmail::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

CiderWebmail::Controller::Root - Root Controller for CiderWebmail

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub default : Private {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body( $c->welcome_message );
}

=head2 auto

Only logged in users may use this product. If no user was found, redirect to the login page.

=cut

sub auto : Private {
    my ($self, $c) = @_;

    if ($c->authenticate({ realm => "CiderWebmail" })) {
        return 1;
    } else {
        return 0;
    }
}

sub login : Local {
    my ( $self, $c ) = @_;
    my $username = $c->req->param('username');
    my $password => $c->req->param('password');

    my $model = $c->model();
}

sub index : Private {
    my ( $self, $c ) = @_;
    my $model = $c->model();
    $c->res->body(join ', ', $model->folders($c));
}

sub mailbox : Local {
    my ( $self, $c ) = @_;
    my $model = $c->model();

    $c->stash( template => 'mailbox.xml' );

    #TODO maybe move this to some 'global' part - we will need it nearly everywhere
    #TODI per-server/per-user INBOX name/seperator/namespace/...
    $c->model->select($c, "INBOX");
    $c->stash( folders => [ $model->folders($c) ] );

    $c->stash( messages => $c->model->messages($c) );
}

sub message : Local {
    my ( $self, $c, $uid ) = @_;
    my $model = $c->model();

    my $message = $c->model->message($c, $uid);

    $c->stash( template => 'message.xml' );
    
    $c->model->select($c, "INBOX");
    $c->stash( folders => [ $model->folders($c) ] );
    $c->stash( message => $message );
}


=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
