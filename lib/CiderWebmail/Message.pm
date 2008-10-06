package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use MIME::Words qw/ decode_mimewords /;
use MIME::Parser;

use DateTime;
use DateTime::Format::Mail;

use Text::Iconv;

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

    #TODO not very clean, maybe there is a better way/module to handle this stuff, if not move this to some seperate module
    my $subject;
    foreach ( decode_mimewords( $self->{c}->stash->{imap}->get_header($self->{'uid'}, "Subject") ) ) {
        if ( defined($_->[1]) ) {
            my $converter = Text::Iconv->new($_->[1], "utf-8");
            $subject .= $converter->convert( $_->[0] );
        } else {
            $subject .= $_->[0];
        }
    }

    return $subject;
}

sub from {
    my ($self) = @_;

    #TODO not very clean, maybe there is a better way/module to handle this stuff, if not move this to some seperate module
    my $from;
    foreach ( decode_mimewords( $self->{c}->stash->{imap}->get_header($self->{'uid'}, "From") ) ) {
        if ( defined($_->[1]) ) {
            my $converter = Text::Iconv->new($_->[1], "utf-8");
            $from .= $converter->convert( $_->[0] );
        } else {
            $from .= $_->[0];
        }
    }

    return $from;
}

sub uri_view {
    my ($self) = @_;

    return $self->{c}->uri_for("/message/view/$self->{uid}");
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
