package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

use Carp qw/ croak /;

=head1 FUNCTIONS

=head2 add_foldertree_uris($c, {folders => $folder_tree, path => 'folder/path', uris => [{action => 'view', uri => 'view_folder'}, ...]})

Adds some URIs to a folder tree.

=cut

sub add_foldertree_uris {
    my $c = shift;
    my $o = shift;
   
    croak unless defined $o->{folders};

    my $separator = $c->model('IMAPClient')->separator($c);

    foreach my $folder ( @{$o->{folders}} ) {
        my $path = (defined($o->{path}) ? join($separator, $o->{path}, $folder->{name}) : $folder->{name});
        my $uri_path = uri_mask_folder_path($path);

        foreach (@{ $o->{uris} }) {
            $folder->{"uri_$_->{action}"} = $c->uri_for("/mailbox/$uri_path/$_->{uri}");
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

=head2 uri_mask_folder_path($path)

Mask all slashes in folder path for use in URIs.

=cut

sub uri_mask_folder_path {
    my ($path) = @_;

    $path =~ s!;!;;!gxm;
    $path =~ s!/!;!gxm;

    return $path;
}

=head2 add_foldertree_to_stash($c)

Gets a folder tree and folders hash from the model, adds 'view' uris and puts them on the stash.

=cut

sub add_foldertree_to_stash {
    my ($c) = @_;

    return if defined($c->stash->{folder_tree});
    my ($tree, $folders_hash) = $c->model('IMAPClient')->folder_tree($c);
    CiderWebmail::Util::add_foldertree_uris($c, { path => undef, folders => $tree->{folders}, uris => [{action => 'view', uri => ''}] });

    $folders_hash->{$c->stash->{folder}}{selected} = 'selected' if $c->stash->{folder};

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

    $c->stash->{folder_data} = $c->stash->{folders_hash}{$c->stash->{folder}};
    $c->stash->{folder_data}{selected} = 'selected';
    $c->stash->{template} = 'folder_tree.xml';

    $c->res->content_type('text/xml');

    return;
}

=head2 filter_unusable_addresses(@addresses)

Filters a list of addresses (string or Mail::Address) to get rid of stuff like 'undisclosed-recipients:'

=cut

sub filter_unusable_addresses {
    my @addresses = @_;
    return grep {(ref $_ ? $_->address : $_) !~ /\A \s* undisclosed [-\s]* recipients:? \s* \z/ixm} @addresses;
}

=head2 message_group_name

formats a date/subject/address for message-grouping
for examples it removes (re:|fwd:) from subjects

=cut

sub message_group_name {
    my ($message, $sort) = @_;

    my $name;

    if ($sort eq 'date') {
        $name = $message->{head}->{date}->ymd;
    }

    if ($sort =~ m/(from|to)/xm) {
        my $address = $message->{head}->{$1}->[0];
        $name = $address ? ($address->name ? $address->address . ': ' . $address->name : $address->address) : 'Unknown';
    }

    if ($sort eq 'subject') {
        $name = $message->{head}->{subject};
        $name =~ s/\A \s+//xm;
        $name =~ s/\A (re: | fwd?:) \s*//ixm;
        $name =~ s/\s+ \z//xm;
    }

    return $name;
}


1;
