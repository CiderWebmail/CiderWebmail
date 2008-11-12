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

Catalyst Model.

=cut


sub die_on_error {
    my ($self, $c) = @_;
  
    if ( $c->stash->{imapclient}->LastError ) {
        
        my $error = $c->stash->{imapclient}->LastError;
        croak $error if $error;
    }
}

sub folders {
    my ($self, $c) = @_;

    my @folders = $c->stash->{imapclient}->folders;
    $self->die_on_error($c);

    return \@folders;
}

sub select {
    my ($self, $c, $o) = @_;

    die 'No mailbox to select' unless $o->{mailbox};

    unless ( $c->stash->{currentmailbox} && ( $c->stash->{currentmailbox} eq $o->{mailbox} ) ) {
        $c->stash->{imapclient}->select( $o->{mailbox} );
        $self->die_on_error($c);
        $c->stash->{currentmailbox} = $o->{mailbox};
    }
}

sub message_count {
    my ($self, $c, $folder) = @_;
    return $c->stash->{imapclient}->message_count($folder);
}

#TODO some way to specify what fields to fetch?
#TODO add data to headercache to speed up other operations (search)
sub fetch_headers_hash {
    my ($self, $c, $o) = @_;

    die 'No mailbox to fetch headers from' unless $o->{mailbox};
    $self->select($c, { mailbox => $o->{mailbox} } );

    return [] unless $c->stash->{imapclient}->message_count;

    my @messages = ();
    my $messages_from_server = $c->stash->{imapclient}->fetch_hash("BODY[HEADER.FIELDS (Subject From To Date)]");
    
    $self->die_on_error($c);

    while ( my ($uid, $data) = each %$messages_from_server ) {
        #we need to add \n to the header text because we only parse headers not a real rfc2822 message
        #otherwise it would skip the last header
        my $email = Email::Simple->new($data->{'BODY[HEADER.FIELDS (Subject From To Date)]'}."\n") || die;
        push( @messages,
            {
                uid => $uid,
                mailbox => $o->{mailbox},
                from => CiderWebmail::Util::decode_header({ header => ($email->header('From') or '') }),
                subject => CiderWebmail::Util::decode_header({ header => ($email->header('Subject') or '') }),
                date => CiderWebmail::Util::date_to_datetime({ date => ($email->header('Date') or '-') }),
            } );
    }
   
    return \@messages;
}

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

#fetch from server
#TODO this is very slow... if a header isn't present in the header cache we should
#do a imap fetch and update the header cache for all 'important' headers in this mail
sub get_header {
    my ($self, $c, $o) = @_;
    
    die unless $o->{mailbox};
    die unless $o->{uid};
    die unless $o->{header};

    $self->select($c, { mailbox => $o->{mailbox} } );

    my $header;

    if ( $o->{cache} ) {
        unless ( $c->stash->{headercache}->get({ uid => $o->{uid}, header => $o->{header} }) ) {
            $c->stash->{headercache}->set({ uid => $o->{uid}, header => $o->{header}, data => $c->stash->{imapclient}->get_header($o->{uid}, $o->{header}) });
            $self->die_on_error($c);
        }

        $header = $c->stash->{headercache}->get({ uid => $o->{uid}, header => $o->{header} });
    } else {
        $header = $c->stash->{imapclient}->get_header($o->{uid}, $o->{header});
        $self->die_on_error($c);
    }
        
    if ( $o->{decode} ) {
        return CiderWebmail::Util::decode_header({ header => $header });
    } else {
        return $header;
    }
}

sub date {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uid not set' unless defined $o->{uid};
    
    my $date = $self->get_header($c,  { header => "Date", uid => $o->{uid}, mailbox => $o->{mailbox}, cache => 1 } );
    $self->die_on_error($c);
    
    if ( defined $date ) {
        return CiderWebmail::Util::date_to_datetime({ date => $date });
    } #FIXME what happens if $date is undef?
}

sub body {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $o->{mailbox};
    die 'uid not set' unless defined $o->{uid};

    $self->select($c, { mailbox => $o->{mailbox} } );

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);
    my $entity = $parser->parse_data( $c->stash->{imapclient}->body_string( $o->{uid} ) );
    $self->die_on_error($c);

    #don't rely on this.. it will change once we support more advanced things
    return join('', @{ $entity->body() });
}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
