package CiderWebmail::Model::IMAPClient;

use strict;
use warnings;
use parent 'Catalyst::Model';

use Mail::IMAPClient;
use CiderWebmail::Message;

=head1 NAME

CiderWebmail::Model::IMAPClient - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

sub folders {
    my ($self, $c) = @_;
    return $c->stash->{imap}->folders;
}

#select mailbox
sub select {
    my ($self, $c, $mailbox) = @_;
    return $c->stash->{imap}->select($mailbox);
}

#all messages in a mailbox
sub messages {
    my ($self, $c, $mailbox) = @_;

    die("mailbox not set") unless defined( $mailbox );
    $self->select($c, $mailbox);

    my @messages = ();
    
    foreach ( $c->stash->{imap}->search("ALL") ) {
        my $uid = $_;
        push(@messages, CiderWebmail::Message->new($c, { uid => $uid } ));
    }

    return \@messages;
}

#fetch a single message
sub message {
    my ($self, $c, $uid) = @_;

    return CiderWebmail::Message->new($c, { uid => $uid } );
}

=head1 AUTHOR

Stefan Seifert

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
