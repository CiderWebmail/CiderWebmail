package CiderWebmail::Message;

use warnings;
use strict;

use CiderWebmail::Message::Forwarded;

use Mail::IMAPClient::BodyStructure;

use Data::ICal;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::Mail;
use HTML::Scrubber;
use HTML::Tidy;
use Mail::Address;
use Text::Iconv;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    #TODO add headers passed here to the header cache
    my $message = {
        c       => $c,
        mailbox => $o->{mailbox},
        uid     => $o->{uid}
    };

    bless $message, $class;
}

sub uid {
    my ($self) = @_;

    return $self->{uid};
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

sub get_header {
    my ($self, $header) = @_;

    return scalar $self->{c}->model('IMAPClient')->get_headers($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, headers => [$header]});
}

#TODO formatting
sub header_formatted {
    my ($self) = @_;

    return $self->{c}->model('IMAPClient')->get_headers_string($self->{c}, { uid => $self->{uid}, mailbox => $self->{mailbox} });
}

sub subject {
    my ($self) = @_;

    return ($self->get_header('subject') or 'No Subject');
}

sub from {
    my ($self) = @_;

    return $self->get_header('from');
}

sub to {
    my ($self) = @_;

    return $self->get_header('to');
}

sub reply_to {
    my ($self) = @_;

    return $self->get_header('reply-to');
}


sub cc {
    my ($self) = @_;

    return $self->get_header('cc');
}

sub mark_read {
    my ($self) = @_;

    $self->{c}->model('IMAPClient')->mark_read($self->{c}, { uid => $self->{uid}, mailbox => $self->{mailbox} });
}

sub get_headers {
    my ($self) = @_;
    
    return {
        subject     => $self->subject(),
        from        => $self->from,
        date        => $self->date->strftime("%F %T"),
        uid         => $self->uid,
    };
}


#returns a datetime object
sub date {
    my ($self) = @_;

    return $self->get_header('date');
}

sub load_body {
    my ($self) = @_;

    return if defined $self->{renderable};

    my $body_parts = $self->body_parts($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
   
    $self->{renderable} = $body_parts->{renderable};
    $self->{attachments} = $body_parts->{attachments};
}

sub renderable {
    my ($self) = @_;

    $self->load_body unless exists $self->{renderable};

    return $self->{renderable};
}

sub renderable_list {
    my ($self) = @_;
    return [ sort { $a->{id} <=> $b->{id} } values %{ $self->renderable } ];
}

sub attachments {
    my ($self) = @_;

    $self->load_body unless exists $self->{attachments};

    return wantarray ? sort { $a->{id} <=> $b->{id} } values %{ $self->{attachments} } : $self->{attachments};
}

sub attachment_list {
    my ($self) = @_;
    return [ sort { $a->{id} <=> $b->{id} } values %{ $self->attachments } ];
}

sub delete {
    my ($self) = @_;

    $self->{c}->model('IMAPClient')->delete_messages($self->{c}, { uids => [ $self->uid ], mailbox => $self->mailbox } );
}

sub move {
    my ($self, $o) = @_;

    die 'target_folder not set' unless defined $o->{target_folder};

    $self->{c}->model('IMAPClient')->move_message($self->{c}, {uid => $self->uid, mailbox => $self->mailbox, target_mailbox => $o->{target_folder}});
}

sub as_string {
    my ($self) = @_;

    $self->{c}->model('IMAPClient')->message_as_string($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub main_body_part {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $self->{mailbox};
    die 'uid not set' unless defined $self->{uid};

    my $renderable = $self->renderable;
  
    #just return the first text/plain part
    #here we should determine the main 'body part' (text/plain > text/html > ???)
    #to use when forwarding/replying to messages and return it
    #FIXME this code does not actually get the first body part. Should use renderable_list here.
    foreach (values %{ $renderable }) {
        my $part = $_;
        if (($part->{is_text} or 0) == 1) {
            return $part->{data};
        }
    }
}

=head2 get_embedded_message

Recursively get an embedded message according to a given path.

=cut

sub get_embedded_message {
    my ( $self, $c, @path ) = @_;

    my $body = $self;
    $body->load_body; # Don't know, why this is needed. Somewhere $body->{renderable} gets initialized with an empty hash

    foreach (@path) {
        $body = $body->renderable->{$_}{data};
        return unless $body;
    }

    return $body;
}

my %part_types = (
    'text/plain'     => \&_render_text_plain,
    'text/html'      => \&_render_text_html,
    'text/calendar'  => \&_render_text_calendar,
    'message/rfc822' => \&_render_message_rfc822,
);

sub body_parts {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $self->{mailbox};
    die 'uid not set' unless defined $self->{uid};

    my $entity;

    if ($self->{entity}) {
        $entity = $self->{entity};
    }
    else {
        my $message = $c->model('IMAPClient')->message_as_string($c, { mailbox => $self->{mailbox}, uid => $self->{uid} });

        my $parser = MIME::Parser->new();
        $parser->output_to_core(1);

        $entity = $parser->parse_data($message);
    }

    my @parts = ($entity);
 
    my $body_parts  = {}; #body parts we render (text/plain, text/html, etc)
    my $attachments = {}; #body parts we don't render (everything else)
    
    my $id = 0;
    while (@parts) {
        my $part = shift @parts;

        if (exists $part_types{$part->effective_type} and not (($part->head->get('content-disposition') or '') =~ /\Aattachment\b/x)) {
            my $rendered_part = $part_types{$part->effective_type}->($self, $c, { part => $part, id => $id });
            $rendered_part->{id} = $id;
            $body_parts->{$id} = $rendered_part;
        }
        elsif ($part->effective_type =~ m!\Amultipart/!) {
            push @parts, $part->parts;
        }
        else {
            $attachments->{$id} = {
                type => $part->effective_type,
                name => ($part->head->mime_attr("content-type.name") or "attachment (".$part->effective_type.")"),
                data => $part->bodyhandle->as_string,
                id   => $id,
                path => ((exists $self->{path} and defined $self->{path}) ? "$self->{path}/" : '') . $id,
            } if $part->bodyhandle;
        }

        $id++;
    }

    return { renderable => $body_parts, attachments => $attachments };
}

sub _render_text_plain {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part_string = $self->_decode_charset($o);

    my $part = {};
    $part->{data} = Text::Flowed::reformat($part_string);
    $part->{is_text} = 1;

    return $part;
}

sub _render_text_calendar {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part_string = $self->_decode_charset($o);

    my $cal = Data::ICal->new(data => $part_string);
    my $dt = DateTime::Format::ISO8601->new;

    my @events;
    foreach ( @{$cal->entries} ) {
        my $entry = $_;
        my $start = $entry->property('dtstart') || next;
        my $end = $entry->property('dtend') || next;
        my $summary = $entry->property('summary') || next;
       
        my $dt_start = $dt->parse_datetime($start->[0]->value);
        my $dt_end = $dt->parse_datetime($end->[0]->value);

        push(@events, {
            start => join("", $dt_start->ymd("-"), ", ", $dt_start->time(":")),
            end => join("", $dt_end->ymd("-"), ", ", $dt_end->time(":")), 
            summary => $summary->[0]->value, }
        );
    }

    my $part = {};
    $part->{data} = \@events;
    $part->{is_calendar} = 1;

    return $part;
}

sub _render_text_html {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $tidy = HTML::Tidy->new( { output_xhtml => 1, bare => 1, clean => 1, doctype => 'omit', enclose_block_text => 1, show_errors => 0, char_encoding => 'utf8', show_body_only => 1, tidy_mark => 0 } );
    my $scrubber = HTML::Scrubber->new( allow => [ qw/p b strong i u hr br div span table thead tbody tr th td/ ] );

    my @default = (
        0   =>    # default rule, deny all tags
        {
            '*'           => 0, # default rule, deny all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
            'class'       => 1,
            'style'       => 1,
        }
    );
    
    $scrubber->default( @default );


    my $part_string = $self->_decode_charset($o);
    
    my $part = {};
    $part->{data} = $scrubber->scrub($part_string);
    $part->{data} = $tidy->clean($part->{data});
    $part->{is_html} = 1;

    return $part;
}

sub _render_message_rfc822 {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part = {};
    
    $part->{data} = CiderWebmail::Message::Forwarded->new($c, { entity => $o->{part}->parts(0), mailbox => $self->{mailbox}, uid => $self->{uid}, path => ((exists $self->{path} and defined $self->{path}) ? "$self->{path}/" : '') . $o->{id} } );
    $part->{data}->load_body();

    $part->{is_message} = 1;

    return $part;
}

sub _decode_charset {
    my ($self, $o) = @_;
    die 'no part set' unless defined $o->{part};

    my $charset = $o->{part}->head->mime_attr("content-type.charset");

    my $part_string;
    unless ($charset
        and eval {
            my $converter = Text::Iconv->new($charset, "utf-8");
            $part_string = $converter->convert($o->{part}->bodyhandle->as_string);
        }) {

        warn "unsupported encoding: $charset" if $charset;
        $part_string = $o->{part}->bodyhandle->as_string;
    }

    utf8::decode($part_string);

    return $part_string;
}

1;
