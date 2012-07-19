package CiderWebmail::Model::IMAPClient;

use parent 'Catalyst::Model';

use Moose;

has _imapclient         => (is => 'rw');
has _cache              => (is => 'rw', isa => 'Object', default => sub { return CiderWebmail::Cache->new(); } );
has _enable_body_search => (is => 'rw', isa => 'Bool', default => 0 );


use MIME::Parser;
use Mail::IMAPClient::MessageSet;
use Mail::IMAPClient::BodyStructure;
use Email::Simple;
use Carp qw(carp croak confess);

use CiderWebmail::Message;
use CiderWebmail::Mailbox;
use CiderWebmail::Util;
use CiderWebmail::Header;
use CiderWebmail::Cache;

=head1 NAME

CiderWebmail::Model::IMAPClient - Catalyst Model

=head1 DESCRIPTION

Interface to the IMAP Server

You should *really* read rfc3501 if you want to use this.

=cut

=head1 METHODS

=head2 new()

creates a new CiderWebmail::Model::IMAPClient

=cut

sub new {
    my $self = shift->next::method(@_);

    if ($Mail::IMAPClient::VERSION =~ m/^3\.2(6|7)/xm) {
        warn "Mail::IMAPClient V3.2(6|7) Unescape workaround enabled. Please upgrade to Mail::IMAPClient >= 3.28\n";
        $self->{_imapclient_unescape_workaround} = 1;
    }


    return $self;
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;

    $self->_imapclient($c->stash->{imapclient});
    $self->_enable_body_search(1) if $c->config->{enable_body_search};

    return $self;
}


=head2 _die_on_error()

die if the last IMAP command sent to the server caused an error
this sould be called after every command sent to the imap server.

=cut

sub _die_on_error {
    my ($self) = @_;
  
    if ( $self->_imapclient->LastError ) {
        my $error = $self->_imapclient->LastError;
        confess $error if $error;
    }

    return;
}

=head2 disconnect

disconnect from IMAP Server, if connected

=cut

sub disconnect {
    my ($self) = @_;

    if (defined($self->_imapclient) && $self->_imapclient->IsConnected ) {
        $self->_imapclient->disconnect();
    }

    return;
}

=head2 separator()

Returnes the folder separator

=cut

#TODO allow override from config file
sub separator {
    my ($self) = @_;

    my $separator = $self->_imapclient->separator;
    $self->_die_on_error();

    return $separator;
}

=head2 folder_tree()

Return all folders as hash-tree.

=cut

sub folder_tree {
    my ($self) = @_;
    
    # sorting folders makes sure branches are created before leafs
    my @folders = sort folder_sort $self->_imapclient->folders;
    $self->_die_on_error();


    my %folder_index = ( '' => { folders => [] } );
    my $separator = $self->separator();

    foreach my $folder (@folders) {
        my ($parent, $name) = $folder =~ /\A (?: (.*) \Q$separator\E)? (.*?) \z/xm;
        $parent = $folder_index{$parent || ''};

        push @{ $parent->{folders} }, $folder_index{$folder} = {
            id     => $folder,
            name   => $name,
            total  => $self->message_count({ mailbox => $folder }),
            unseen => $self->unseen_count({ mailbox => $folder }),
        };
    }

    return wantarray ? ($folder_index{''}, \%folder_index) : $folder_index{''};
}


=head2 folder_sort

custom sort for folders
always put INBOX on top

=cut

sub folder_sort {
    return 1 if (lc($b) eq 'inbox');

    return lc($a) cmp lc($b);
}


=head2 select({ mailbox => $mailbox })

selects a folder

=cut

sub select {
    my ($self, $o) = @_;

    croak 'No mailbox to select' unless $o->{mailbox};

    unless ( $self->_imapclient->Folder and $self->_imapclient->Folder eq $o->{mailbox} ) {
        $self->_imapclient->select( $o->{mailbox} );
        $self->_die_on_error();
    }

    return;
}

=head2 message_count({ mailbox => $mailbox })

returnes the number of messages in a mailbox

=cut

sub message_count {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};

    return $self->_imapclient->message_count($o->{mailbox});
}

=head2 unseen_count({ mailbox => $mailbox })

returnes the number of unseen messages in a mailbox

=cut

sub unseen_count {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};

    return $self->_imapclient->unseen_count($o->{mailbox});
}

=head2 check_sort($sort)

Checks if the given sort criteria is valid.

=cut

sub check_sort {
    my ($sort) = @_;

    croak ("illegal char in sort: $_") if $_ !~ /\A (?:reverse \s+)? (arrival | cc | date | from | size | subject | to) \z/ixm;

    return;
}

=head2 get_folder_uids({ mailbox => $mailbox, sort => $sort, range => $range })

Returns a MessageSet object representing all UIDs in a mailbox
The range option accepts a range of UIDs (for example 1:100 or 1:*), if you specify a range containing '*' the last (highest UID) message will always be returned.

=cut

sub get_folder_uids {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{sort};

    my @search;
    if ($o->{range}) {
        croak unless ($o->{range} =~ m/\A\d+:(\d+|\*)\Z/mx);
        @search = ( 'UID', $o->{range} );
    } else {
        @search = ( 'ALL' );
    }

    $self->select({ mailbox => $o->{mailbox} } );

    foreach (@{ $o->{sort} }) {
        check_sort($_);
    }

    #TODO empty result
    my @sort = ( '('.join(" ", @{ $o->{sort} }).')', 'UTF-8' );

    return $self->_imapclient->sort(@sort, @search);
}

=head2 get_headers_hash({ uids => [qw/ 1 .. 10 /], sort => [qw/ date /], headers => [qw/ date subject /], mailbox => 'INBOX' })
   
returnes a array of hashes for messages in a mailbox

=over 4

=item * uids (arrayref): a list of uids (as described in RFC2060) to fetch

=item * sort (arrayref): sort criteria (as described in RFC2060). for example: [ qw/ date / ] will sort by date, [ qw/ reverse date / ] will sort by reverse date

=item * headers (arrayref, required): a list of mail-headers to fetch.

=item * mailbox (required)

=back

=cut

#TODO update headercache
sub get_headers_hash {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{headers};

    my $uids;           #uids we will fetch, MessageSet object!
    my @messages;       #messages wo got back, contains 'transformed' headers
    my @words;          #things we expect in return from the imap server

    my $headers_to_fetch = uc(join(" ", @{ $o->{headers} }));
    
    $self->select({ mailbox => $o->{mailbox} } );
    
    if ($o->{uids}) {
        croak("sorting a list of UIDs is not implemented yet, you have to specify uids OR sort") if $o->{sort};
        croak("uids needs to be an arrayref") unless ( ref($o->{uids}) eq "ARRAY" );

        foreach (@{ $o->{uids} }) {
            croak("illegal char in uid $_") if /\D/xm;
        }

        $uids = Mail::IMAPClient::MessageSet->new($o->{uids});
    } else {
        #TODO allow custom search?
        #TODO empty folder
        #TODO shortcut for fetch ALL
        $uids = $self->_imapclient->search("ALL");
    }

    if ($o->{sort}) {
        croak("sorting a list of UIDs is not implemented yet, you have to specify uids OR sort") if $o->{uids};
        croak("sort needs to be an arrayref") unless ( ref($o->{sort}) eq "ARRAY" );
       
        foreach (@{ $o->{sort} }) {
            check_sort($_);
        }

        my @sort = ( '('.join(" ", @{ $o->{sort} }).')', 'UTF-8', 'ALL' );
        $uids = $self->_imapclient->sort(@sort);
        return [] unless @$uids;
    }

    my @items;
    push(@items, "BODYSTRUCTURE");
    push(@items, "FLAGS");
    push(@items, "BODY.PEEK[HEADER.FIELDS ($headers_to_fetch)]");
    my $hash = $self->_imapclient->fetch_hash($uids, @items);

    $self->_die_on_error();

    while (my ($uid, $entry) = each(%$hash)) {
        my $message;
        $message->{uid}     = $uid;
        $message->{mailbox} = $o->{mailbox};

        my $headers;

        if (defined($self->{_imapclient_unescape_workaround})) {
            $headers = $self->_imapclient->Unescape($entry->{"BODY[HEADER.FIELDS ($headers_to_fetch)]"});
        } else {
            $headers = $entry->{"BODY[HEADER.FIELDS ($headers_to_fetch)]"};
        }

        #we need to add \n to the header text because we only parse headers not a real rfc2822 message
        #otherwise it would skip the last header
        my $email = Email::Simple->new($headers."\n") || croak;

        my %headers = $email->header_pairs;
        defined $headers{$_} or $headers{$_} = '' foreach @{ $o->{headers} }; # make sure all requested headers are at least present

        while ( my ($header, $value) = each(%headers) ) {
            $header = lc $header;
            $message->{head}->{$header} = CiderWebmail::Header::transform({ type => $header, data => ($value or '') });
        }

        $message->{flag} = {};
        if ($entry->{FLAGS}) {
            my $flags = lc $entry->{FLAGS};
            $flags =~ s/\\//gxm;
            $message->{flags} = $flags;
            $message->{flag}{$_} = $_ foreach split /\s+/xm, $flags;
        }

        if($entry->{BODYSTRUCTURE}) {
            my $dummy = " * 123 FETCH (UID 123 BODYSTRUCTURE ($entry->{BODYSTRUCTURE}))";
            my $struct = Mail::IMAPClient::BodyStructure->new($dummy);
            foreach(@{ $struct->{bodystructure} }) {
                if (defined $_->{bodydisp}->{attachment}) {
                    $message->{attachments} = 1;
                    last;
                }
            }
        }

        push(@messages, $message);
    }

    return \@messages;
}

=head2 search()

searches a mailbox
returns a arrayref containing a list of UIDs

=cut

#search in FROM/SUBJECT
#FIXME report empty result
sub search {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{searchfor};
    $self->select({ mailbox => $o->{mailbox} });

    my @search = ();

    #see imap rfc about searching with utf8 and string literals about how to generate this
    utf8::encode($o->{searchfor}); #utf-8 encoded search string
    my $search_string_length = length($o->{searchfor}); #length of the search string in bytes

    my $quoted_search_terms = "{$search_string_length}\r\n$o->{searchfor}";

    push(@search, 'OR', 'BODY', $quoted_search_terms) if $self->_enable_body_search;

    push(@search, 'OR');
    push(@search, 'SUBJECT', $quoted_search_terms);
    push(@search, 'FROM', $quoted_search_terms);

    my @uids;
    if ($o->{sort}) {
        foreach (@{ $o->{sort} }) {
            check_sort($_);
        }
        my @sort = ( '('.join(" ", @{ $o->{sort} }).')', 'UTF-8' );
        @uids = $self->_imapclient->sort(@sort, @search);
    }
    else {
        @uids = $self->_imapclient->search(@search);
    }
    $self->_die_on_error();

    return wantarray ? @uids : \@uids; 
}

=head2 all_headers({ mailbox => $mailbox, uid => $uid })

fetch all headers for a message and updates the local headercache

=cut

sub all_headers {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{uid};

    $self->select({ mailbox => $o->{mailbox} } );
    

    unless ($self->_cache->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, key => '_parsed_header' })) {
        $self->_cache->set({ uid => $o->{uid}, mailbox => $o->{mailbox}, key => '_parsed_header', data => $self->_imapclient->parse_headers($o->{uid}, "ALL") });
    }

    my $fetched_headers = $self->_cache->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, key => '_parsed_header' });


    my $headers = {}; 

    my $header = "";

    while (my ($headername, $headervalue) = each(%$fetched_headers)) {
        $headervalue = join("\n", @$headervalue);
        $headername = lc($headername);
        $headers->{$headername} = $headervalue;
        $self->_cache->set({ uid => $o->{uid}, key => $headername, data => $headervalue, mailbox => $o->{mailbox} });
        $headers->{$headername} = $headervalue;
        $header .= join("", $headername, ": ", $headervalue, "\n");
    }

    return $headers;
}

=head2 get_headers({ mailbox => $mailbox })

fetch headers for a single message from the server or (if available) the local headercache

=cut

sub get_headers {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{uid};
    croak unless $o->{headers};

    $self->select({ mailbox => $o->{mailbox} } );

    my $headers = {};

    foreach(@{ $o->{headers} }) {
        my $header = lc($_);
        #if we are missing *any* of the headers fetch all headers from the imap server and store it in the request cache
        unless ( $self->_cache->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, key => $header }) ) {
            my $fetched_headers = $self->all_headers({ mailbox => $o->{mailbox}, uid => $o->{uid} });
            $headers->{$header} = CiderWebmail::Header::transform({ type => $header, data => $fetched_headers->{$header}});
        } else {
            $headers->{$header} = CiderWebmail::Header::transform({ type => $header, data => $self->_cache->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, key => $header })});
        }
    }

    return (wantarray ? $headers : $headers->{lc($o->{headers}->[0])});
}

=head2 mark_read({ mailbox => $mailbox, uid => $uid })

mark a messages as read

=cut

sub mark_read {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{uid};

    $self->select({ mailbox => $o->{mailbox} });
    $self->_imapclient->set_flag("Seen", $o->{uid});

    return;
}

=head2 mark_answered({ mailbox => $mailbox, uid => $uid })

mark a message as answered

=cut

sub mark_answered {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};
    croak unless $o->{uid};

    $self->select({ mailbox => $o->{mailbox} });
    $self->_imapclient->set_flag("Answered", $o->{uid});

    return;
}

=head2 bodypart_as_string({ mailbox => $mailbox, uid => $uid, parts => [ $part ] })

fetches body part(s) of a message - part IDs according to the bodystructure of the message

=cut

sub bodypart_as_string {
    my ($self, $o) = @_;

    croak('mailbox not set') unless defined $o->{mailbox};
    croak('uid not set') unless defined $o->{uid};

    $self->select({ mailbox => $o->{mailbox} } );

    my $bodypart_string = $self->_imapclient->bodypart_string( $o->{uid}, $o->{part} );
    $self->_die_on_error();

    return $bodypart_string;
}

=head2 get_bodystructure({ mailbox => $mailbox, uid => $uid })

fetches bodystructure of a message.
returns a Mail::IMAPClient::BodyStructure object - this might change when we parse
this into something more usefull

=cut

sub get_bodystructure {
    my ($self, $o) = @_;

    croak('mailbox not set') unless defined $o->{mailbox};
    croak('uid not set') unless defined $o->{uid};

    $self->select({ mailbox => $o->{mailbox} } );

    my $bodystructure = $self->_imapclient->get_bodystructure( $o->{uid} );
    $self->_die_on_error();

    return $bodystructure;
}

=head2 message_as_string({ mailbox => $mailbox, uid => $uid })

return a full message body as string

=cut

sub message_as_string {
    my ($self, $o) = @_;

    croak('mailbox not set') unless defined $o->{mailbox};
    croak('uid not set') unless defined $o->{uid};

    $self->select({ mailbox => $o->{mailbox} } );

    my $message_string = $self->_imapclient->message_string( $o->{uid} );
    $self->_die_on_error();

    return $message_string;
}

=head2 delete_messages({ mailbox => $mailbox, uid => $uid })

delete message(s) form the server and expunge the mailbox

=cut

sub delete_messages {
    my ($self, $o) = @_;

    croak('mailbox not set') unless defined $o->{mailbox};
    croak('uids not set') unless defined $o->{uids};

    $self->select({ mailbox => $o->{mailbox} } );

    $self->_imapclient->delete_message($o->{uids});
    $self->_die_on_error();

    $self->_imapclient->expunge($o->{mailbox});
    $self->_die_on_error();

    return;
}

=head2 append_message({ mailbox => $mailbox, message_text => $message_text })

low level method to append an RFC822-formatted message to a mailbox

=cut

sub append_message {
    my ($self, $o) = @_;
    return $self->_imapclient->append($o->{mailbox}, $o->{message_text});
}

=head2 move_message({ mailbox => $mailbox, target_mailbox => $target_mailbox, uid => $uid })

Move a message to another mailbox

=cut

sub move_message {
    my ($self, $o) = @_;

    $self->select({ mailbox => $o->{mailbox} });
    $self->_imapclient->move($o->{target_mailbox}, $o->{uid}) or croak("could not move message $o->{uid} to folder $o->{mailbox}");
    $self->_die_on_error();
    
    $self->_imapclient->expunge($o->{mailbox});
    $self->_die_on_error();

    return;
}

=head2 create_mailbox({ mailbox => $mailbox, name => $name })

Create a subfolder

=cut

sub create_mailbox {
    my ($self, $o) = @_;

    croak unless $o->{name};

    return $self->_imapclient->create($o->{mailbox} ? join $self->separator(), $o->{mailbox}, $o->{name} : $o->{name});
}

=head2 delete_mailbox({ mailbox => $mailbox })

Delete a complete folder

=cut

sub delete_mailbox {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};

    return $self->_imapclient->delete($o->{mailbox});
}

=head2 get_quotas({ mailbox => $mailbox })

Get a list of quotaroots that apply to the specified mailbox

=cut

sub get_quotas {
    my ($self, $o) = @_;

    croak unless $o->{mailbox};

    my @quota_response = $self->_imapclient->tag_and_run("GETQUOTAROOT $o->{mailbox}");
    $self->_die_on_error();

    my @quotas;
    foreach(@quota_response) {
        if ($_ =~ m/QUOTA\s+\"([^"]+?)\"\s+\(STORAGE\s+(\d+)\s+(\d+)\)/) {
            my ($name, $cur, $max) = ($1, $2, $3);
            push(@quotas, { cur => int($cur/1024), max => int($max/1024), unit => 'MByte', percent => int($cur / ($max/100)), type => 'storage', name => $name });
        }
    }

    return \@quotas;
}


=head1 AUTHOR

Stefan Seifert and
Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
