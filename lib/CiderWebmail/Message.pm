package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use MIME::WordDecoder;
use MIME::Parser;

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

    unless ( defined( $self->{'entity'} ) ) {
        my $parser = MIME::Parser->new();
        $parser->output_to_core(1);
        $self->{'entity'} = $parser->parse_data( $self->{c}->stash->{imap}->body_string( $self->{'uid'} ) );
    }

    #don't rely on this.. it will change once we support more advanced things
    return join('', @{ $self->{'entity'}->body() });
}

1;
