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

    if ($c->sessionid and not $c->session->{ended} and $c->authenticate({ realm => 'CiderWebmail' })) {
        $c->stash( headercache => CiderWebmail::Headercache->new($c) );

        #IMAPClient setup
        $c->stash->{imapclient}->Ranges(1);
 
        my ($tree, $folders_hash) = $c->model('IMAPClient')->folder_tree($c);
        CiderWebmail::Util::add_foldertree_uris($c, { path => undef, folders => $tree->{folders}, uris => [{action => 'view', uri => ''}] });

        $c->stash({
            folder_tree   => $tree,
            folders_hash  => $folders_hash,
            uri_mailboxes => $c->uri_for('/mailboxes'),
            uri_logout    => $c->uri_for('/logout'),
        });

        return 1;
    }

    if ($c->sessionid and $c->session->{ended}) {
        $c->delete_session('logged out');
    }

    $c->session; # start new session

    my $realm = $c->get_auth_realm($c->config->{authentication}{default_realm});
    $realm->credential->authorization_required_response($c, $realm, { realm => 'CiderWebmail' });

    return 0;
}

=head2 logout

Logout action: markes the current session as ended

=cut

sub logout : Local {
    my ( $self, $c ) = @_;

    $c->session->{ended} = 1;

    $c->stash({ template => 'logout.xml' });
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
        $_->{name} =~ /\Ainbox\z/i and $inbox = $_ foreach @$folders; # try to find a folder named INBOX
        $inbox ||= reduce { $a->{name} lt $b->{name} ? $a : $b } @$folders; # no folder named INBOX
    }
    else {
        $inbox = $folders->[0]; # only one folder, so this must be INBOX
    }

    $c->res->redirect($inbox->{uri_view});
}

=head2 mailboxes

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
        ]
    });

    $c->stash({
        template          => 'mailboxes.xml',
        uri_create_folder => $c->uri_for('create_folder'),
    });
}

=head2 create_folder

Create a top level folder

=cut

sub create_folder : Local {
    my ( $self, $c ) = @_;

    if (my $name = $c->req->param('name')) {
        $c->model('IMAPClient')->create_mailbox($c, {name => $name});
        $c->res->redirect($c->uri_for('mailboxes'));
    }

    $c->stash({
        template => 'create_mailbox.xml',
    });
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
