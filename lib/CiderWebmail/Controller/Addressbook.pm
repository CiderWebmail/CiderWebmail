package CiderWebmail::Controller::Addressbook;
use Moose;

use Carp qw/ croak /;

use CiderWebmail::Util;
use Email::Valid;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

CiderWebmail::Controller::Addressbook - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

redirect to addressbook/list

=cut

sub index : Private {
    my ($self, $c) = @_;

    $c->res->redirect($c->uri_for('/addressbook/list'));

    return;
}

=head2 setup

common function used to setup addressbook

=cut

sub setup : Chained('/') PathPart('addressbook') CaptureArgs(0) {
    my ($self, $c) = @_;

    CiderWebmail::Util::add_foldertree_to_stash($c);

    return;
}

=head2 list

list addressbook contents

=cut

sub list : Chained('/addressbook/setup') PathPart('list') Args(0) {
    my ($self, $c) = @_;

    #todo move compose to /compose instead of /mailbox/FOO/compose or figure out the mailbox here
    $c->stash->{uri_compose} = $c->uri_for("/mailbox/INBOX/compose");
    $c->stash->{uri_addressbook} = $c->uri_for("/addressbook");

    my @addresses = $c->model('DB::Addressbook')->search({ user => $c->user->id })->all;
    $c->stash->{addresses} = \@addresses;

    $c->stash->{template} = 'addressbook/list.xml';

    $c->detach();

    return;
}

=head2 modify

common setup function for addressbook modify operations (add, delete, edit)

=cut

sub modify : Chained('/addressbook/setup') Path('modify') CaptureArgs(0) {
    my ($self, $c) = @_;

    if ($c->req->param('update')) {
        $c->stash->{error} = "All fields need to be filled out" unless ($c->req->param('firstname') =~ m/\w+/xm);
        $c->stash->{error} = "All fields need to be filled out" unless ($c->req->param('surname') =~ m/\w+/xm);
        $c->stash->{error} = "All fields need to be filled out" unless ($c->req->param('email') && Email::Valid->address($c->req->param('email')));

        return if $c->stash->{error};

        my $addressbook = $c->model('DB::Addressbook');

        my $entry;
        if (defined $c->req->param('id') and ($c->req->param('id') =~ m/^\d+$/xm)) {
            $entry = $addressbook->find($c->req->param('id'));
        }

        if (defined $entry) {
            croak("entry does not belong to user") unless $entry->user eq $c->user->id;
            $entry->update({
                firstname => $c->req->param('firstname'),
                surname => $c->req->param('surname'),
                email => $c->req->param('email'),
                user => $c->user->id });

        }
        else {
            $c->model('DB::Addressbook')->create({
                firstname => $c->req->param('firstname'),
                surname => $c->req->param('surname'),
                email => $c->req->param('email'),
                user => $c->user->id });
        }

        $c->forward('list');
    }

    return;
}

=head2 edit

edit addressbook entry

=cut

sub edit : Chained('/addressbook/modify') PathPart('edit') Args(1) {
    my ($self, $c, $id ) = @_;

    my $entry  = $c->model('DB::Addressbook')->search({ user => $c->user->id, id => $id })->first;
    croak("entry not found in addressbook") unless $entry;

    $c->stash->{id} = $entry->id;
    $c->stash->{firstname} = $entry->firstname;
    $c->stash->{surname} = $entry->surname;
    $c->stash->{email} = $entry->email;

    $c->stash->{uri_modify} = $c->uri_for('/addressbook/modify/edit', $id);

    $c->stash->{template} = 'addressbook/edit.xml';

    return;
}

=head2 add

add addressbook entry

=cut

sub add : Chained('/addressbook/modify') PathPart('add') Args(0) {
    my ($self, $c ) = @_;

    $c->stash->{firstname} = $c->req->param('firstname');
    $c->stash->{surname} = $c->req->param('surname');
    $c->stash->{email} = $c->req->param('email');

    #we only have a name (for example from an email "From" header), attemt a best-effort to split it into first and surname
    if ($c->req->param('name')) {
        if ($c->req->param('name') =~ m/^(\w+)/mx) {
            $c->stash->{firstname} = $1;
        }

        if ($c->req->param('name') =~ m/\w+\s*(.*)/mx) {
            $c->stash->{surname} = $1;
        }
    }

    $c->stash->{uri_modify} = $c->uri_for('/addressbook/modify/add');

    $c->stash->{template} = 'addressbook/edit.xml';

    return;
}

=head2 delete

delete addressbook entry

=cut

sub delete : Chained('/addressbook/setup') Path('delete') Args(1) {
    my ($self, $c, $id) = @_;

    $c->model('DB::Addressbook')->search({ user => $c->user->id, id => $id })->delete;

    $c->forward('list');

    return;
}

=head1 AUTHOR

Mathias Reitinger,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
