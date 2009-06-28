package CiderWebmail::Model::IMAPClient;

use strict;
use warnings;
use parent 'Catalyst::Model';

use MIME::Parser;
use MIME::Words qw/ decode_mimewords /;
use Mail::IMAPClient::MessageSet;
use Email::Simple;
use Text::Flowed;
use Mail::Address;
use Carp qw(croak confess);

use CiderWebmail::Message;
use CiderWebmail::Mailbox;
use CiderWebmail::Util;
=head1 NAME

CiderWebmail::Model::IMAPClient - Catalyst Model

=head1 DESCRIPTION

Interface to the IMAP Server

You should *really* read rfc3501 if you want to use this.

=cut

=head1 METHODS

=head2 _die_on_error($c)

die if the last IMAP command sent to the server caused an error
this sould be called after every command sent to the imap server.

=cut

sub _die_on_error {
    my ($self, $c) = @_;
  
    if ( $c->stash->{imapclient}->LastError ) {
        
        my $error = $c->stash->{imapclient}->LastError;
        warn $error if $error;
        croak $error if $error;
    }
}

=head2 separator($c)

Returnes the folder separator

=cut

#TODO allow override from config file
sub separator {
    my ($self, $c) = @_;

    unless(defined $c->stash->{separator}) {
        $c->stash->{separator} = $c->stash->{imapclient}->separator;
        $self->_die_on_error($c);
    }

    return $c->stash->{separator};
}

=head2 folder_tree($c)

Return all folders as hash-tree.

=cut

sub folder_tree {
    my ($self, $c) = @_;
    
    # sorting folders makes sure branches are created before leafs
    my @folders = sort { lc($a) cmp lc($b) } $c->stash->{imapclient}->folders;
    $self->_die_on_error($c);

    my %folder_index = ( '' => { folders => [] } );
    my $separator = $self->separator($c);

    foreach my $folder (@folders) {
        my ($parent, $name) = $folder =~ /\A (?: (.*) \Q$separator\E)? (.*?) \z/x;
        $parent = $folder_index{$parent || ''};

        push @{ $parent->{folders} }, $folder_index{$folder} = {
            id     => $folder,
            name   => $name,
            total  => $self->message_count($c, { mailbox => $folder }),
            unseen => $self->unseen_count($c, { mailbox => $folder }),
        };
    }

    return wantarray ? ($folder_index{''}, \%folder_index) : $folder_index{''};
}


=head2 select($c, { mailbox => $mailbox })

selects a folder

=cut

sub select {
    my ($self, $c, $o) = @_;

    die 'No mailbox to select' unless $o->{mailbox};

    unless ( $c->stash->{imapclient}->Folder and $c->stash->{imapclient}->Folder eq $o->{mailbox} ) {
        $c->stash->{imapclient}->select( $o->{mailbox} );
        $self->_die_on_error($c);
    }
}

=head2 message_count($c, { mailbox => $mailbox })

returnes the number of messages in a mailbox

=cut

sub message_count {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};

    return $c->stash->{imapclient}->message_count($o->{mailbox});
}

=head2 unseen_count($c, { mailbox => $mailbox })

returnes the number of unseen messages in a mailbox

=cut

sub unseen_count {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};

    return $c->stash->{imapclient}->unseen_count($o->{mailbox});
}

=head2 get_folder_uids($c, { mailbox => $mailbox })

Returns a MessageSet object representing all UIDs in a mailbox

=cut

sub get_folder_uids {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{sort};

    $self->select($c, { mailbox => $o->{mailbox} } );

    #TODO check RFC if we need to allow more here
    foreach (@{ $o->{sort} }) {
        die ("illegal char in sort") if ($_ =~ m/[^a-zA-Z ]/);
    }

    #TODO empty result
    my @sort = ( '('.join(" ", @{ $o->{sort} }).')', 'UTF-8', 'ALL' );
    return $c->stash->{imapclient}->sort(@sort);
}

=head2 get_headers_hash($c, { uids => [qw/ 1 .. 10 /], sort => [qw/ date /], headers => [qw/ date subject /], mailbox => 'INBOX' })
   
returnes a array of hashes for messages in a mailbox

=over 4

=item * uids (arrayref): a list of uids (as described in RFC2060) to fetch

=item * sort (arrayref): sort criteria (as described in RFC2060). for example: [ qw/ date / ] will sort by date, [ qw/ reverse date / ] will sort by reverse date

=item * headers (arrayref, required): a list of mail-headers to fetch.

=item * mailbox (required)

=back

=cut

#TODO update headercache
sub get_headers_hash() {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{headers};

    my $uids;           #uids we will fetch, MessageSet object!
    my @messages;       #messages wo got back, contains 'transformed' headers
    my @words;     #things we expect in return from the imap server

    my $headers_to_fetch = join(" ", @{ $o->{headers} });
    push (@words, 'FLAGS');
    push(@words, "BODY[HEADER.FIELDS ($headers_to_fetch)]");

    
    $self->select($c, { mailbox => $o->{mailbox} } );
    
    if ($o->{uids}) {
        die "sorting a list of UIDs is not implemented yet, you have to specify uids OR sort" if $o->{sort};
        die "sort needs to be an arrayref" unless ( ref($o->{uids}) eq "ARRAY" );

        foreach (@{ $o->{uids} }) {
            die ("illegal char in uid list") if ($_ =~ m/[^0-9]/);
        }

        $uids = Mail::IMAPClient::MessageSet->new($o->{uids});
    } else {
        #TODO allow custom search?
        #TODO empty folder
        #TODO shortcut for fetch ALL
        $uids = $c->stash->{imapclient}->search("ALL");
    }

    if ($o->{sort}) {
        die "sorting a list of UIDs is not implemented yet, you have to specify uids OR sort" if $o->{uids};
        die "sort needs to be an arrayref" unless ( ref($o->{sort}) eq "ARRAY" );
       
        #TODO check RFC if we need to allow more here
        foreach (@{ $o->{sort} }) {
            die ("illegal char in sort") if ($_ =~ m/[^a-zA-Z]/);
        }

        my @sort = ( '('.join(" ", @{ $o->{sort} }).')', 'UTF-8', 'ALL' );
        $uids = $c->stash->{imapclient}->sort(@sort);
        return [] unless @$uids;
    }

    my $lines = $c->stash->{imapclient}->fetch($uids, "(BODY.PEEK[HEADER.FIELDS ($headers_to_fetch)] FLAGS)");
    $self->_die_on_error($c);

    for (my $index = 0;  $index <= scalar(@$lines) ; $index++) {
        my $line = $lines->[$index];
        my $entry = {};     #not processed data of the current message
        my $message = {};   #final data of the current message
        my $uid;            #uid of the current message
        my $data;           #header data of the current message
      
        next unless $line;
        next if ($line =~ m/UID FETCH/);

        $uid = $line =~ /\bUID\s+(\d+)/i ? $1 : undef;
        next unless defined $uid;

        $message->{uid}     = $uid;
        $message->{mailbox} = $o->{mailbox};
      
        #from Mail::IMAPClient
        foreach my $w (@words) {
            if($line =~ /\Q$w\E\s*$/i ) {
               $entry->{$w} = $lines->[$index+1];
               $entry->{$w} =~ s/(?:\n?\r)+$//g;
               chomp $entry->{$w};
            } else {
                $line =~ /\(      # open paren followed by ...
                    (?:.*\s)?  # ...optional stuff and a space
                    \Q$w\E\s   # escaped fetch field<sp>
                    (?:"       # then: a dbl-quote
                      (\\.|    # then bslashed anychar(s) or ...
                       [^"]+)  # ... nonquote char(s)
                    "|         # then closing quote; or ...
                    \(         # ...an open paren
                      (\\.|    # then bslashed anychar or ...
                       [^\)]+) # ... non-close-paren char
                    \)|        # then closing paren; or ...
                    (\S+))     # unquoted string
                    (?:\s.*)?  # possibly followed by space-stuff
                    \)         # close paren
                /xi;
                $entry->{$w} = defined $1 ? $1 : defined $2 ? $2 : $3;
            }
        }

        #we need to add \n to the header text because we only parse headers not a real rfc2822 message
        #otherwise it would skip the last header
        my $email = Email::Simple->new($entry->{"BODY[HEADER.FIELDS ($headers_to_fetch)]"}."\n") || die;

        my %headers = $email->header_pairs;
        defined $headers{$_} or $headers{$_} = '' foreach @{ $o->{headers} }; # make sure all requested headers are at least present

        while ( my ($header, $value) = each(%headers) ) {
            $header = lc $header;
            $message->{head}->{$header} = $self->transform_header($c, { header => $header, data => ($value or '') }),
        }


        #this is FUBAR we should return an array with the flags and use this in the template
        if ($entry->{FLAGS}) {
            $message->{flags} = lc($entry->{FLAGS});
            $message->{flags} =~ s/\\//g;
        }

        push(@messages, $message);
    }

    return \@messages;
}

=head2 simple_search()

searches a mailbox From/Subject headers
returns a arrayref containing a list of UIDs

=cut

#search in FROM/SUBJECT
#FIXME report empty result
#TODO body search?
sub simple_search {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{searchfor};
    $self->select($c, { mailbox => $o->{mailbox} });

    my @search = (
        'OR',
        'SUBJECT', $c->stash->{imapclient}->Quote($o->{searchfor}),
        'FROM', $c->stash->{imapclient}->Quote($o->{searchfor}),
    );

    my @uids = $c->stash->{imapclient}->search(@search);
    $self->_die_on_error($c);

    return \@uids; 
}

=head2 get_headers_string($c, { mailbox => $mailbox, uid => $uid })

returnes the fullheader of a message as a string

=cut

sub get_headers_string {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} } );

    if (exists $c->stash->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{_fullheader}) {
        return $c->stash->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{_fullheader};
    } else {
        $self->all_headers($c, { mailbox => $o->{mailbox}, uid => $o->{uid} });
        return $c->stash->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{_fullheader};
    }
}

=head2 all_headers($c, { mailbox => $mailbox, uid => $uid })

fetch all headers for a message and updates the local headercache

=cut

sub all_headers {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} } );
    
    my $fetched_headers = $c->stash->{imapclient}->parse_headers($o->{uid}, "ALL");
    my $headers = {}; 

    my $header = "";

    while (my ($headername, $headervalue) = each(%$fetched_headers)) {
        $headervalue = join("\n", @$headervalue);
        $headername = lc($headername);
        $headers->{$headername} = $headervalue;
        $c->stash->{headercache}->set({ uid => $o->{uid}, header => $headername, data => $headervalue, mailbox => $o->{mailbox} });
        $headers->{$headername} = $headervalue;
        $header .= join("", $headername, ": ", $headervalue, "\n");
    }

    $c->stash->{requestcache}->{$o->{mailbox}}->{$o->{uid}}->{_fullheader} = $header;
    return $headers;
}

=head2 get_headers($c, { mailbox => $mailbox })

fetch headers for a single message from the server or (if available) the local headercache

=cut

sub get_headers {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};
    die unless $o->{headers};

    $self->select($c, { mailbox => $o->{mailbox} } );

    my $headers = {};

    foreach(@{ $o->{headers} }) {
        my $header = lc($_);
        #if we are missing *any* of the headers fetch all headers from the imap server and store it in the request cache
        unless ( $c->stash->{headercache}->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, header => $header }) ) {
            my $fetched_headers = $self->all_headers($c, { mailbox => $o->{mailbox}, uid => $o->{uid} });
            $headers->{$header} = $self->transform_header($c, { header => $header, data => $fetched_headers->{$header}});
        } else {
            $headers->{$header} = $self->transform_header($c, { header => $header, data => $c->stash->{headercache}->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, header => $header })});
        }
    }

    return (wantarray ? $headers : $headers->{lc($o->{headers}->[0])});
}

=head2 mark_read($c, { mailbox => $mailbox, uid => $uid })

mark a messages as read

=cut

sub mark_read {
    my ($self, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} });
    $c->stash->{imapclient}->set_flag("Seen", $o->{uid});
}

=head2 message_as_string($c, { mailbox => $mailbox, uid => $uid })

return a full message body as string

=cut

sub message_as_string {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uid not set' unless defined $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} } );

    my $message_string = $c->stash->{imapclient}->message_string( $o->{uid} );
    utf8::decode($message_string);

    unless($c->stash->{headercache}->get({uid => $o->{uid}, mailbox => $o->{mailbox}, header => '_messagestring'})) {
        $c->stash->{headercache}->set({uid => $o->{uid}, mailbox => $o->{mailbox}, header => '_messagestring', data => $message_string});
    }

    return $c->stash->{headercache}->get({uid => $o->{uid}, mailbox => $o->{mailbox}, header => '_messagestring'});
}

=head2 delete_messages($c, { mailbox => $mailbox, uid => $uid })

delete message(s) form the server and expunge the mailbox

=cut

sub delete_messages {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uids not set' unless defined $o->{uids};

    $self->select($c, { mailbox => $o->{mailbox} } );

    $c->stash->{imapclient}->delete_message($o->{uids});
    $self->_die_on_error($c);

    $c->stash->{imapclient}->expunge($o->{mailbox});
    $self->_die_on_error($c);
}

=head2 append_message($c, { mailbox => $mailbox, message_text => $message_text })

low level method to append an RFC822-formatted message to a mailbox

=cut

sub append_message {
    my ($self, $c, $o) = @_;
    $c->stash->{imapclient}->append($o->{mailbox}, $o->{message_text});
}

=head2 move_message($c, { mailbox => $mailbox, target_mailbox => $target_mailbox, uid => $uid })

Move a message to another mailbox

=cut

sub move_message {
    my ($self, $c, $o) = @_;

    $self->select($c, { mailbox => $o->{mailbox} });
    $c->stash->{imapclient}->move($o->{target_mailbox}, $o->{uid}) or die "could not move message $o->{uid} to folder $o->{mailbox}";
    $self->_die_on_error($c);
    
    $c->stash->{imapclient}->expunge($o->{mailbox});
    $self->_die_on_error($c);
}

=head2 create_mailbox($c, { mailbox => $mailbox, name => $name })

Create a subfolder

=cut

sub create_mailbox {
    my ($self, $c, $o) = @_;

    die unless $o->{name};

    $c->stash->{imapclient}->create($o->{mailbox} ? join $self->separator($c), $o->{mailbox}, $o->{name} : $o->{name});
}

=head2 transform_header($c, { header => $header_name, data => $header_data })

'transform' a header from the 'raw' state (the way it was returned from the server) to an appropriate object.
if no appropriate object exists the header will be decoded (using decode_mimewords()) and UTF-8 encoded

the following 'transformations' take place:

=over 4

=item * from -> Mail::Address object

=item * to -> Mail::Address object

=item * cc -> Mail::Address object

=item * date -> DateTime object

=back

=cut

sub transform_header {
    my ($self, $c, $o) = @_;

    die unless defined $o->{header};
    return undef unless defined $o->{data};

    $o->{header} = lc($o->{header});

    my $headers = {
        from       => \&_transform_address,
        to         => \&_transform_address,
        cc         => \&_transform_address,
        'reply-to' => \&_transform_address,
        date       => \&_transform_date,
    };

    return $headers->{$o->{header}}->($self, $c, $o) if exists $headers->{$o->{header}};

    #if we have no appropriate transfrom function decode the header and return it
    return $self->_decode_header($c, { data => ($o->{data} or '')})
}

sub _transform_address {
    my ($self, $c, $o) = @_;

    return undef unless defined $o->{data};

    my @address = Mail::Address->parse($self->_decode_header($c, $o));
   
    return \@address;
}

sub _transform_date {
    my ($self, $c, $o) = @_;

    return '' unless defined $o->{data};

    #some mailers specify (CEST)... Format::Mail isn't happy about this
    #TODO better solution
    $o->{data} =~ s/\([a-zA-Z]+\)$//;

    my $dt = DateTime::Format::Mail->new();
    $dt->loose;

    my $date = eval { $dt->parse_datetime($o->{data}) };
    unless ($date) {
        warn "$@ parsing $o->{data}";
        $date = DateTime->from_epoch(epoch => 0); # just return a DateTime object so we can continue
    }

    return $date;
}

sub _decode_header {
    my ($self, $c, $o) = @_;

    return '' unless defined $o->{data};

    my $header;

    foreach ( decode_mimewords( $o->{data} ) ) {
        if ( @$_ > 1 ) {
            unless (eval {
                    my $converter = Text::Iconv->new($_->[1], "utf-8");
                    my $part = $converter->convert( $_->[0] );
                    utf8::decode($part);
                    $header .= $part if defined $part;
                }) {
                warn "unsupported encoding: $_->[1]";
                utf8::decode($_->[0]);
                $header .= $_->[0];
            }
        } else {
            utf8::decode($_->[0]);
            $header .= $_->[0];
        }
    }

    return $header;
}

=head1 AUTHOR

Stefan Seifert and
Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
