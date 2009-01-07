package CiderWebmail::Model::IMAPClient;

use strict;
use warnings;
use parent 'Catalyst::Model';

use MIME::Parser;
use Email::Simple;
use Carp qw(croak confess);

use CiderWebmail::Message;
use CiderWebmail::Mailbox;
use CiderWebmail::Util;
=head1 NAME

CiderWebmail::Model::IMAPClient - Catalyst Model

=head1 DESCRIPTION

Interface to the IMAP Server

=cut

=head1 METHODS

=head2 die_on_error()

die if the last IMAP command sent to the server caused an error

=cut

sub die_on_error {
    my ($self, $c) = @_;
  
    if ( $c->stash->{imapclient}->LastError ) {
        
        my $error = $c->stash->{imapclient}->LastError;
        warn $error if $error;
        croak $error if $error;
    }
}

=head2 folders()

list all aviable folders

=cut

sub folders {
    my ($self, $c) = @_;

    my @folders = $c->stash->{imapclient}->folders;

    $self->die_on_error($c);

    @folders = sort { lc($a) cmp lc($b) } @folders;

    return \@folders;
}

=head2 separator()

Returnes the folder separator

=cut
#TODO allow override from config file
sub separator {
    my ($self, $c) = @_;

    unless(defined $c->stash->{separator}) {
        $c->stash->{separator} = $c->stash->{imapclient}->separator;
        $self->die_on_error($c);
    }

    return $c->stash->{separator};
}

=head2 folder_tree()

Return all folders as hash-tree.

=cut

sub folder_tree {
    my ($self, $c) = @_;
    
    # sorting folders makes sure branches are created before leafs
    my @folders = sort { lc($a) cmp lc($b) } $c->stash->{imapclient}->folders;
    $self->die_on_error($c);

    my %folder_index = ( '' => { folders => [] } );
    my $separator = $self->separator($c);

    foreach my $folder (@folders) {
        my ($parent, $name) = $folder =~ /\A (?: (.*) \Q$separator\E)? (.*?) \z/x;
        $parent = $folder_index{$parent || ''};

        push @{ $parent->{folders} }, $folder_index{$folder} = {
            id     => $folder,
            name   => $name,
            total  => $self->message_count($c, $folder),
            unseen => $self->unseen_count($c, $folder),
        };
    }

    return wantarray ? ($folder_index{''}, \%folder_index) : $folder_index{''};
}


=head2 select()

selects a folder

=cut

sub select {
    my ($self, $c, $o) = @_;

    die 'No mailbox to select' unless $o->{mailbox};

    unless ( $c->stash->{currentmailbox} and $c->stash->{currentmailbox} eq $o->{mailbox} ) {
        $c->stash->{imapclient}->select( $o->{mailbox} );
        $self->die_on_error($c);
        $c->stash->{currentmailbox} = $o->{mailbox};
    }
}

=head2 message_count($folder)

returnes the number of messages in a folder

=cut

sub message_count {
    my ($self, $c, $folder) = @_;
    return $c->stash->{imapclient}->message_count($folder);
}

=head2 unseen_count($folder)

returnes the number of unseen messages in a folder

=cut

sub unseen_count {
    my ($self, $c, $folder) = @_;
    return $c->stash->{imapclient}->unseen_count($folder);
}

=head2 fetch_headers_hash()

returns a arrayref of hashes containing a hash for every message in
the mailbox

=cut

#TODO some way to specify what fields to fetch?
sub fetch_headers_hash {
    my ($self, $c, $o) = @_;

    die 'No mailbox to fetch headers from' unless $o->{mailbox};
    $self->select($c, { mailbox => $o->{mailbox} } );

    return [] unless $c->stash->{imapclient}->message_count;

    my @messages = ();
    my $messages_from_server = $c->stash->{imapclient}->fetch_hash("BODY[HEADER.FIELDS (Subject From To Date)]", 'FLAGS');

    $self->die_on_error($c);

    while ( my ($uid, $data) = each %$messages_from_server ) {
        #we need to add \n to the header text because we only parse headers not a real rfc2822 message
        #otherwise it would skip the last header
        my %flags = map {m/(\w+)/; (lc $1 => lc $1)} split / /, $data->{FLAGS};
        my $email = Email::Simple->new($data->{'BODY[HEADER.FIELDS (Subject From To Date)]'}."\n") || die;

        #TODO we need some way to pass an array to {headercache}->set... this looks ridiculous
        $c->stash->{headercache}->set( {
            uid     => $uid,
            mailbox => $o->{mailbox},
            header  => $_,
            data    => CiderWebmail::Util::decode_header({ header => ($email->header($_) or '')})
        }) foreach qw(From To Subject Date);

        push @messages, {
            uid     => $uid,
            mailbox => $o->{mailbox},
            from    => CiderWebmail::Util::decode_header({ header => ($email->header('From') or '') }),
            subject => CiderWebmail::Util::decode_header({ header => ($email->header('Subject') or '') }),
            date    => CiderWebmail::Util::date_to_datetime({ date => ($email->header('Date') or '-') }),
            flags   => join (' ', keys %flags),
            unseen  => not exists $flags{seen},
            %flags,
        };
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
        'HEADER SUBJECT', $c->stash->{imapclient}->Quote($o->{searchfor}),
        'HEADER FROM', $c->stash->{imapclient}->Quote($o->{searchfor}),
    );

    my @uids = $c->stash->{imapclient}->search(@search);
    $self->die_on_error($c);

    return \@uids; 
}

=head2 all_headers()

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

=head2 get_headers()

fetch headers from the server or (if available) the local headercache

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
            $headers->{$header} = $fetched_headers->{$header};
        } else {
            $headers->{$header} =  $c->stash->{headercache}->get({ uid => $o->{uid}, mailbox => $o->{mailbox}, header => $header });
        }
    }

    return (wantarray ? $headers : $headers->{lc($o->{headers}->[0])});
}

=head2 date()
 
fetch a date header from the server or the local headercache

=cut

sub date {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uid not set' unless defined $o->{uid};

    my $date = $self->get_headers($c, { headers => [qw/Date/], uid => $o->{uid}, mailbox => $o->{mailbox} } );

    #FIXME what happens if $date is undef?
    if ( defined $date ) {
        return CiderWebmail::Util::date_to_datetime({ date => $date });
    } 
}

=head2 message_as_string()

return a full message body as string

=cut

sub message_as_string {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uid not set' unless defined $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} } );

    return $c->stash->{imapclient}->message_string( $o->{uid} );
}

=head2 body()

fetch the body from the server

=cut

sub body {
    my ($self, $c, $o) = @_;

    my $message = $self->message_as_string($c, $o);

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);

    my $entity = $parser->parse_data($message);
    my $error = $c->stash->{imapclient}->LastError;
    return $error if $error;

    my @parts = $entity->parts_DFS;
    @parts = ($entity) unless @parts;

    my $body = '';
    my @attachments;
    my $id = 0;

    foreach (@parts) {
        my $part_head = $_->head;
        my $part_body = $_->bodyhandle;

        if ($_->effective_type =~ m!\Atext/plain\b!) {
            my $charset = $part_head->mime_attr("content-type.charset");
            if ($part_body) {
                unless (eval {
                        my $converter = Text::Iconv->new($charset, "utf-8");
                        $body .= $converter->convert($part_body->as_string);
                    }) {

                    warn "unsupported encoding: $charset";
                    $body .= $part_body->as_string;
                }
            }
        }
        else {
            push @attachments, {
                type => $_->effective_type,
                name => ($part_head->mime_attr("content-type.name") or "attachment (".$_->effective_type.")"),
                data => $part_body->as_string,
                id   => $id++,
            } if $part_body;
        }
    }

    return wantarray ? ($body, \@attachments) : $body; # only give attachments to those who are interested
}

=head2 delete_messages()

delete message(s) form the server and expunge the mailbox

=cut

sub delete_messages {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uids not set' unless defined $o->{uids};

    $self->select($c, { mailbox => $o->{mailbox} } );

    $c->stash->{imapclient}->delete_message($o->{uids});
    $self->die_on_error($c);

    $c->stash->{imapclient}->expunge($o->{mailbox});
    $self->die_on_error($c);
}

=head2 append_message($c, {mailbox, message_text})

low level method to append an RFC822-formatted message to a mailbox

=cut

sub append_message {
    my ($self, $c, $o) = @_;
    $c->stash->{imapclient}->append($o->{mailbox}, $o->{message_text});
}

=head2 move_message($c {uid, mailbox, target_mailbox})

Move a message to another mailbox

=cut

sub move_message {
    my ($self, $c, $o) = @_;

    $self->select($c, { mailbox => $o->{mailbox} });
    $c->stash->{imapclient}->move($o->{target_mailbox}, $o->{uid}) or die "could not move message $o->{uid} to folder $o->{mailbox}";
    $self->die_on_error($c);
    
    $c->stash->{imapclient}->expunge($o->{mailbox});
    $self->die_on_error($c);

}

=head1 AUTHOR

Stefan Seifert and
Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
