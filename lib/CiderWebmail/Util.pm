package CiderWebmail::Util;

use warnings;
use strict;

use Exporter;
use base qw(Exporter);

our @EXPORT = qw(decode_mime_words);

use Text::Iconv;
use MIME::Words qw/ decode_mimewords /;

use DateTime;
use DateTime::Format::Mail;

use Crypt::Util;
use Crypt::Random::Source qw/get_weak/;
use MIME::Base64;

use Carp qw/ carp croak /;

use feature qw/ switch /;


=head1 FUNCTIONS

=head2 add_foldertree_uris($c, {folders => $folder_tree, path => 'folder/path', uris => [{action => 'view', uri => 'view_folder'}, ...]})

Adds some URIs to a folder tree.

=cut

sub add_foldertree_uris {
    my $c = shift;
    my $o = shift;
   
    croak unless defined $o->{folders};

    my $separator = $c->model('IMAPClient')->separator();

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
    my ($tree, $folders_hash) = $c->model('IMAPClient')->folder_tree();
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

=head2 encrypt({ string => $string })

encrypt a string

=cut

sub encrypt {
    my ($c, $o) = @_;

    croak("empty string passed to CiderWebmail::Util::decrypt") unless defined($o->{string});
    croak("cannot encrypt without active session") unless $c->sessionid;

    my $util = Crypt::Util->new;

    my $key = CiderWebmail::Util::get_key($c);
    croak("invalid key passed to CiderWebmail::Util::crypt") unless (defined($key) && (length($key) == 48));

    $util->default_key($key);
    return $util->encode_string_uri_base64( $util->encrypt_string($o->{string}) );
}

=head2 decrypt({ string => $string })

decrypt a string

=cut

sub decrypt {
    my ($c, $o) = @_;

    croak("empty string passed to CiderWebmail::Util::decrypt") unless defined($o->{string});
    croak("cannot decrypt without active session") unless $c->sessionid;

    my $util = Crypt::Util->new;
    my $key = CiderWebmail::Util::get_key($c);

    croak("invalid key passed to CiderWebmail::Util::crypt") unless (defined($key) && (length($key) == 48));

    $util->default_key($key);
    return $util->decrypt_string( $util->decode_string_uri_base64( $o->{string} ) );
}

=head2 get_key()

gets the server-side encryption key
if no key exists one will be created

=cut


sub get_key {
    my ($c, $o) = @_;

    croak("cannot fetch encryption key without active session") unless $c->sessionid;

    if (defined($c->session->{encryption_key}) && (length($c->session->{encryption_key}) == 48)) {
        return $c->session->{encryption_key};
    }  else {
        $c->session->{encryption_key} = encode_base64(get_weak(35));
        chomp($c->session->{encryption_key});
        return $c->session->{encryption_key};
    }
}

sub parse_message_id {
    my ($message_id) = @_;

    croak('parse_message_id($message_id) called without $message_id') unless defined $message_id;

    #message id's are in the format <message uid on IMAP server>/<CiderWebmail::Part id in @CiderWebmail::Message::parts>
    if ($message_id =~ m|^(\d+)/([a-z0-9\.]+)$|ixm) {
        return ($1, $2);
    } else {
        croak("Unable to parse in_reply_to: $message_id");
    }
}

sub decode_mime_words {
    my ($o) = @_;

    return '' unless defined $o->{data};

    my $string;

    foreach ( decode_mimewords( $o->{data} ) ) {
        if ( @$_ > 1 ) {
            unless (eval {
                    my $converter = Text::Iconv->new($_->[1], "utf-8");
                    my $part = $converter->convert( $_->[0] );
                    utf8::decode($part);
                    $string .= $part if defined $part;
                }) {
                carp("unable to convert $_->[1] to utf-8 using Text::Iconv: $!");
                utf8::decode($_->[0]);
                $string .= $_->[0];
            }
        } else {
            utf8::decode($_->[0]);
            $string .= $_->[0];
        }
    }

    return $string;
}


1;
