#not sure if this is 'the right way to do it(tm)'
#no idea how this will scale to a 100k messages mailbox...
package CiderWebmail::Model::IMAPClient::Message;

use warnings;
use strict;
use parent 'CiderWebmail::Model::IMAPClient';

use MIME::WordDecoder;
use DateTime;
use DateTime::Format::Mail;

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

    return MIME::WordDecoder::unmime($self->{c}->stash->{imap}->subject($self->{'uid'}));
}

sub from {
    my ($self) = @_;

    return MIME::WordDecoder::unmime($self->{c}->stash->{imap}->get_header($self->{'uid'}, "From"));
}

#returns a datetime object
sub date {
    my ($self) = @_;

    my $date = $self->{c}->stash->{imap}->get_header($self->{'uid'}, "Date");
   
    #some mailers specify (CEST)... Format::Mail isn't happy about this
    #TODO better solution
    $date =~ s/\([a-zA-Z]+\)$//;

    return DateTime::Format::Mail->parse_datetime($date);
}

1;
