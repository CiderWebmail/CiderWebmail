package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

=head1 FUNCTIONS

=head2 add_foldertree_uris($c, {folders => $folder_tree, path => 'folder/path', uris => [{action => 'view', uri => 'view_folder'}, ...]})

Adds some URIs to a folder tree.

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

=head2 add_foldertree_to_stash($c)

Gets a folder tree and folders hash from the model, adds 'view' uris and puts them on the stash.

=cut

sub add_foldertree_to_stash {
    my ($c) = @_;

    return if defined($c->stash->{folder_tree});
    my ($tree, $folders_hash) = $c->model('IMAPClient')->folder_tree($c);
    CiderWebmail::Util::add_foldertree_uris($c, { path => undef, folders => $tree->{folders}, uris => [{action => 'view', uri => ''}] });

    $c->stash({
        folder_tree   => $tree,
        folders_hash  => $folders_hash,
    });

    return;
}

=head2 send_foldertree_update($c)

Common function to reply to a request with a new folder tree. Used in AJAX commands.

=cut

sub send_foldertree_update {
    my ($c) = @_;

    CiderWebmail::Util::add_foldertree_to_stash($c); # update folder display

    $c->stash->{folders_hash}{$c->stash->{folder}}{selected} = 'selected';
    $c->stash->{template} = 'folder_tree.xml';

    $c->res->content_type('text/xml');

    return;
}

=head2 filter_unusable_addresses(@addresses)

Filters a list of addresses (string or Mail::Address) to get rid of stuff like 'undisclosed-recipients:'

=cut

sub filter_unusable_addresses {
    return grep {(ref $_ ? $_->address : $_) !~ /\A \s* undisclosed [-\s]* recipients:? \s* \z/ixm} @_;
}

1;
