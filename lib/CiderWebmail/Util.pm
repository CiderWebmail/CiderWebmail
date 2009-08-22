package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

=head1 FUNCTIONS

=head2 add_foldertree_uris

Adds some URIs to a folder tree.
Accepts a parameter hash:
    { folders => $folder_tree, path => 'folder/path', uris => [{action => 'view', uri => 'view_folder'}, ...] }

=cut

sub add_foldertree_uris {
    my $c = shift;
    my $o = shift;
   
    die unless defined $o->{folders};

    my $separator = $c->model('IMAPClient')->separator($c);

    foreach my $folder ( @{$o->{folders}} ) {
        my $path = (defined($o->{path}) ? join($separator, $o->{path}, $folder->{name}) : $folder->{name});
        foreach (@{ $o->{uris} }) {
            $folder->{"uri_$_->{action}"} = $c->uri_for("/mailbox/$path/$_->{uri}");
        }
        
        if (defined($folder->{folders})) { #if we have any subfolders
            add_foldertree_uris($c, {
                path    => $path,
                folders => $folder->{folders},
                uris    => $o->{uris},
            });
        }
    }

    return;
}

=head2 add_foldertree_to_stash

Gets a folder tree and folders hash from the model, adds 'view' uris and puts them on the stash.

=cut

sub add_foldertree_to_stash {
    my ($c) = @_;

    my ($tree, $folders_hash) = $c->model('IMAPClient')->folder_tree($c);
    CiderWebmail::Util::add_foldertree_uris($c, { path => undef, folders => $tree->{folders}, uris => [{action => 'view', uri => ''}] });

    $c->stash({
        folder_tree   => $tree,
        folders_hash  => $folders_hash,
    });
}

=head2 send_foldertree_update

Common function to reply to a request with a new folder tree. Used in AJAX commands.

=cut

sub send_foldertree_update {
    my ($c) = @_;
    CiderWebmail::Util::add_foldertree_to_stash($c); # update folder display
    $c->stash->{folders_hash}{$c->stash->{folder}}{selected} = 'selected';
    $c->stash({ template => 'folder_tree.xml' });
    $c->res->content_type('text/xml');
}

1;
