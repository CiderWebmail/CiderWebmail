#not sure if this is 'the right way to do it(tm)'
#no idea how this will scale to a 100k messages mailbox...
package CiderWebmail::Model::IMAPClient::Message;

use warnings;
use strict;
use parent 'CiderWebmail::Model::IMAPClient';

sub new {
    my ($class, $c, $o) = @_;

    my $message = {
        c => $c,
        uid => $o->{'uid'},
    };

    bless $message, $class;
}

sub subject {
    my ($self) = @_;

    return $self->{c}->stash->{imap}->subject($self->{'uid'});
}

1;
