package CiderWebmail::Message;

use warnings;
use strict;

use MIME::WordDecoder;
use Mail::IMAPClient::BodyStructure;
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

sub uid {
    my ($self) = @_;

    return $self->{'uid'};
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

sub body {
    my ($self) = @_;

    return Mail::IMAPClient::BodyStructure->new( $self->{c}->stash->{imap}->fetch($self->{uid}, "bodystructure"));
}

1;
