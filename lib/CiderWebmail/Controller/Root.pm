package CiderWebmail::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

use CiderWebmail::Headercache;
use List::Util qw(reduce);

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

=head2 auto

Only logged in users may use this product.

=cut

sub auto : Private {
    my ($self, $c) = @_;

    if ($c->sessionid and $c->session->{username} and $c->authenticate({ id => $c->session->{username}, password => $c->session->{password} })) {
        $c->stash( headercache => CiderWebmail::Headercache->new(c => $c) );

        #IMAPClient setup
        $c->stash->{imapclient}->Ranges(1);

        CiderWebmail::Util::add_foldertree_to_stash($c);

        $c->stash({
            uri_mailboxes => $c->uri_for('/mailboxes'),
            uri_logout    => $c->uri_for('/logout'),
        });

        return 1;
    }

    # Give the user a chance to authenticate
    $c->forward('login');
    return 0;
}

=head2 login

Login action.
Private action that auto forwards to so we can prepend it do a login on any URI and on successful login show the requested page.

=cut

sub login : Private {
    my ( $self, $c ) = @_;

    my %user_data = (
            username => $c->req->param('username'),
            password => $c->req->param('password'),
        );

    if ($user_data{username} and $user_data{password}) {
        if ($c->authenticate(\%user_data)) {
            $c->session->{$_} = $user_data{$_} foreach qw(username password); # save for repeated IMAP authentication

            return $c->res->redirect($c->req->uri);
        }
        else {
            $c->stash({ message => 'Invalid username/password' }); #TODO I18N
        }
    }

    $c->stash({ template => 'login.xml' });

    return;
}


=head2 logout

Logout action: drops the current session and logs out the user.
Redirects to / so we can start a new session.

=cut

sub logout : Local {
    my ( $self, $c ) = @_;

    $c->logout;
    $c->delete_session('logged out');

    return $c->res->redirect($c->uri_for('/'));
}

=head2 index

Redirect to the INBOX view

=cut

sub index : Private {
    my ( $self, $c ) = @_;
    my $model = $c->model('IMAPClient');
    my $folders = $c->stash->{folder_tree}{folders};
    my $inbox;

    if (@$folders > 1) {
        $_->{name} =~ /\Ainbox\z/xmi and $inbox = $_ foreach @$folders; # try to find a folder named INBOX
        $inbox ||= reduce { $a->{name} lt $b->{name} ? $a : $b } @$folders; # no folder named INBOX
    }
    else {
        $inbox = $folders->[0]; # only one folder, so this must be INBOX
    }

    return $c->res->redirect($inbox->{uri_view});
}

=head2 mailboxes

Lists the folders of this user. Used by AJAX to update the folder tree.

=cut

sub mailboxes : Local {
    my ( $self, $c ) = @_;

    my $tree = $c->stash->{folder_tree};

    CiderWebmail::Util::add_foldertree_uris($c, {
        path    => undef,
        folders => $tree->{folders},
        uris    => [
            {action => 'view',             uri => ''},
            {action => 'create_subfolder', uri => 'create_subfolder'},
            {action => 'delete',           uri => 'delete'},
        ]
    });

    $c->stash({
        template          => 'mailboxes.xml',
        uri_create_folder => $c->uri_for('create_folder'),
    });

    return;
}

=head2 create_folder

Create a top level folder

=cut

sub create_folder : Local {
    my ( $self, $c ) = @_;

    if (my $name = $c->req->param('name')) {
        $c->model('IMAPClient')->create_mailbox($c, {name => $name});

        return $c->res->redirect($c->uri_for('mailboxes'));
    }

    $c->stash({
        template => 'create_mailbox.xml',
    });

    return;
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
