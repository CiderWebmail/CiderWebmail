package CiderWebmail::Controller::Managesieve;
use Moose;
use namespace::autoclean;

use feature 'switch';

use Carp qw/ confess /;

BEGIN { extends 'Catalyst::Controller'; }

=head2 setup

load sieve script list from server

=cut

sub setup : Chained('/') PathPart('managesieve') CaptureArgs(0) {
    my ($self, $c) = @_;

    CiderWebmail::Util::add_foldertree_to_stash($c);

    $c->stash->{uri_add} = $c->uri_for('edit');

    my $sieve = $c->model('Managesieve')->new();

    $sieve->login({
        username => $c->session->{'username'},
        password => CiderWebmail::Util::decrypt($c, { string => $c->req->cookie('password')->value }),
    });

    $c->stash->{_managesieve} = $sieve;

    return;
}

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->res->redirect($c->uri_for('list'));
}


sub list : Chained('/managesieve/setup') PathPart('list') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'managesieve/list.xml';

    my $scripts = $c->stash->{_managesieve}->list_scripts();

    my %sieve_scripts = map {
        $_ => {
            active      => $scripts->{$_},
            uri_edit    => $c->uri_for('edit', { sieve_script_name => $_ }),
            uri_delete  => $c->uri_for('delete', { sieve_script_name => $_ }),
        } } keys %$scripts;
    $c->stash->{sieve_scripts} = \%sieve_scripts;

    return;
}

sub delete : Chained('/managesieve/setup') PathPart('delete') Args() {
    my ($self, $c) = @_;

    my $managesieve = $c->stash->{_managesieve};

    #TODO validate against allowed names per RFC
    $managesieve->delete_script({ name => $c->req->param('sieve_script_name') });

    $c->res->redirect($c->uri_for('list'));
    $c->detach;
}

sub edit : Chained('/managesieve/setup') PathPart('edit') Args() {
    my ($self, $c) = @_;

    my $managesieve = $c->stash->{_managesieve};

    $c->stash->{template} = 'managesieve/edit.xml';
    $c->stash->{uri_save} = $c->uri_for('edit');


    #TODO validate against allowed names per RFC
    $c->stash->{sieve_script_name} = $c->req->param('sieve_script_name');

    #TODO better parameter validation before detach to save
    if (defined $c->req->param('sieve_script_save')) {

        if (defined($c->req->param('sieve_script_original_name')) and ($c->req->param('sieve_script_name') ne $c->req->param('sieve_script_original_name'))) {
            $managesieve->rename_script({ old_name => $c->req->param('sieve_script_original_name'), new_name => $c->req->param('sieve_script_name') });
        }

        #TODO use Net::Sieve::Script to at least parse it here so we can perform basic validation
        $c->stash->{sieve_script_content} = $c->req->param('sieve_script_content');
        $c->stash->{sieve_script_status} = ((defined $c->req->param('sieve_script_active')) ? 'active' : 'inactive');

        $c->detach('save');
    }
    
    if (defined $c->req->param('sieve_script_name')) {
        $c->stash->{sieve_script_content} = $managesieve->get_script({ name => $c->stash->{sieve_script_name} });
        $c->stash->{sieve_script_active} = ($c->stash->{sieve_script_name} eq $managesieve->active_script);

        #this is used to detect if the user requested a rename
        $c->stash->{sieve_script_original_name} = $c->req->param('sieve_script_name');
    }
}

=head2 save

save a managescript save to the server
the following variables need to be set on the stash:

sieve_script_name     => name of the script on the server. if it does not exist it will be created. if it does exist it will be overwritten
sieve_script_content  => sieve script to save
sieve_script_status   => if set to to 'active' the script will be marked as 'active' on the server, this will disable all other scripts.
                         if set to to 'inactive' the script will be marked as 'inactive' on the server.

=cut

sub save : Chained('/managesieve/setup') Args(0) {
    my ($self, $c) = @_;

    my $managesieve = $c->stash->{_managesieve};

    confess("Managesieve::save() called but sieve_script_name not set on the stash") unless defined $c->stash->{sieve_script_name};
    confess("Managesieve::save() called but sieve_script_content not set on the stash") unless defined $c->stash->{sieve_script_content};
    confess("Managesieve::save() called but sieve_script_status not set on the stash") unless defined $c->stash->{sieve_script_status};

    my $name = $c->stash->{sieve_script_name};
    my $content = $c->stash->{sieve_script_content};
    my $status = $c->stash->{sieve_script_status};

    $managesieve->put_script({ name => $name, content => $content });

    given($status) {
        when('active') { $managesieve->active_script({ name => $name }); }
        when('inactive') { $managesieve->disable_script({ name => $name }); }
        default { confess("stash sieve_script_status set to invalid value: " . $status); }
    };

    $c->forward('list');

    return;
}

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
