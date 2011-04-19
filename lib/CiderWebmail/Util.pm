package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

use Crypt::Util;
use Crypt::Random::Source qw/get_weak/;
use MIME::Base64;

use Carp qw/ croak /;

use feature qw/ switch /;


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

=head2 add_foldertree_icons($c, {folders => $folder_tree})

Adds some icons to a folder tree.

=cut

sub add_foldertree_icons {
    my $c = shift;
    my $o = shift;
   
    croak unless defined $o->{folders};

    foreach my $folder ( @{$o->{folders}} ) {
        given(lc($folder->{name})) {
            when('inbox')       { $folder->{icon} = 'inbox.png'; }
            when('sent')        { $folder->{icon} = 'sent.png'; }
            when('trash')       { $folder->{icon} = 'trash.png'; }
            default             { $folder->{icon} = 'folder.png'; }
        }

        if (defined($folder->{folders})) { #if we have any subfolders
            add_foldertree_icons($c, {
                folders => $folder->{folders},
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
    CiderWebmail::Util::add_foldertree_icons($c, { folders => $tree->{folders} });

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

=head2 crypt({ username => $username, string => $string })

encrypt a string

=cut

sub crypt {
    my ($c, $o) = @_;

    croak unless defined $o->{username};
    die("empty string passed to CiderWebmail::Util::crypt") unless defined($o->{string});
    my $util = Crypt::Util->new;

    my $key = CiderWebmail::Util::get_key($c, $o);
    croak("invalid key passed to CiderWebmail::Util::crypt") unless (defined($key) && (length($key) > 20));

    $util->default_key($key);
    my $string = $util->encode_string_uri_base64( $util->encrypt_string($o->{string}) );

    return $string;
}

=head2 decrypt({ username => $username, string => $string })

decrypt a string

=cut

sub decrypt {
    my ($c, $o) = @_;

    croak unless defined $o->{username};
    croak("empty string passed to CiderWebmail::Util::decrypt") unless defined($o->{string});
    my $util = Crypt::Util->new;

    my $key = CiderWebmail::Util::get_key($c, $o);
    croak("invalid key passed to CiderWebmail::Util::crypt") unless (defined($key) && (length($key) > 20));
    $util->default_key($key);
    my $string = $util->decrypt_string( $util->decode_string_uri_base64( $o->{string} ) );

    return $string;
}

=head2 get_key()

gets the server-side encryption key
if no key exists one will be created

=cut


sub get_key {
    my ($c, $o) = @_;

    croak unless defined $o->{username};

    my $settings = $c->model('DB::Settings')->find_or_new({user => $o->{'username'} });

    if (defined($settings->encryption_key) && (length($settings->encryption_key) > 20)) {
        return $settings->encryption_key;
    }  else {
        my $new_key = encode_base64(get_weak(35));
        chomp($new_key);
        $settings->set_column(encryption_key => $new_key);
        $settings->update_or_insert();
        return $settings->encryption_key;
    }
}

1;
