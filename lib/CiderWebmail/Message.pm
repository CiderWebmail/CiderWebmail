package CiderWebmail::Message;

use Moose;

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
use Data::ICal;
use DateTime::Format::ISO8601;
use CiderWebmail::Util;

has c           => (is => 'ro', isa => 'Object');
has mailbox     => (is => 'ro', isa => 'Str');
has uid         => (is => 'ro', isa => 'Int');
has renderable  => (is => 'rw', isa => 'HashRef');
has attachments => (is => 'rw', isa => 'HashRef');
has loaded      => (is => 'rw');

has entity      => (is => 'ro', isa => 'Object');
has path        => (is => 'ro', isa => 'Str');

=head2 get_header($header)

Returns the first value found for the named header

=cut

sub get_header {
    my ($self, $header) = @_;

    return scalar $self->c->model('IMAPClient')->get_headers($self->c, { uid => $self->uid, mailbox => $self->mailbox, headers => [$header]});
}

=head2 header_formatted()

Returns the full message header formatted for output

=cut

#TODO formatting
sub header_formatted {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->get_headers_string($self->c, { uid => $self->uid, mailbox => $self->mailbox });
}

=head2 subject()

Shortcut getting the subject or 'No Subject' if none is available.

=cut

sub subject {
    my ($self) = @_;

    return ($self->get_header('subject') or 'No Subject');
}

=head2 from()

Shortcut for getting the 'from' header

=cut

sub from {
    my ($self) = @_;

    return $self->get_header('from');
}

=head2 to()

Shortcut for getting the 'to' header

=cut

sub to {
    my ($self) = @_;

    return $self->get_header('to');
}

=head2 reply_to()

Shortcut for getting the 'reply-to' header

=cut

sub reply_to {
    my ($self) = @_;

    return $self->get_header('reply-to');
}


=head2 cc()

Shortcut for getting the 'CC' header

=cut

sub cc {
    my ($self) = @_;

    return $self->get_header('cc');
}

=head2 guess_recipient()

Tries to guess the recipient address used to deliver this message to this mailbox.
Used for suggesting a From address on reply/forward.

=cut

sub guess_recipient {
    my ($self) = @_;

    return [] unless defined $self->to;
    return [ CiderWebmail::Util::filter_unusable_addresses(@{ $self->to }) ]
}

=head2 mark_read()

Mark the message as read

=cut

sub mark_read {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->mark_read($self->c, { uid => $self->uid, mailbox => $self->mailbox });
}

=head2 date()

Returns the 'date' header as datetime object

=cut

sub date {
    my ($self) = @_;

    return $self->get_header('date');
}

=head2 load_body()

Loads the message body and populates the renderable and attachments structures if not already done.

=cut

sub load_body {
    my ($self) = @_;

    return if $self->loaded;
    $self->loaded(1);

    my $body_parts = $self->body_parts($self->c, { uid => $self->uid, mailbox => $self->mailbox } );
   
    $self->renderable($body_parts->{renderable});
    $self->attachments($body_parts->{attachments});

    return;
}

before qw(renderable attachments) => sub {
    my ($self) = @_;
    $self->load_body();
};

=head2 renderable_list()

Returns a sorted list of renderable body parts.

=cut

sub renderable_list {
    my ($self) = @_;
    return [ sort { $a->{id} <=> $b->{id} } values %{ $self->renderable } ];
}

=head2 attachment_list()

Returns a sorted list of attachments.

=cut

sub attachment_list {
    my ($self) = @_;
    return [ sort { $a->{id} <=> $b->{id} } values %{ $self->attachments } ];
}

=head2 delete()

Deletes the message from the server.

=cut

sub delete {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->delete_messages($self->c, { uids => [ $self->uid ], mailbox => $self->mailbox } );
}

=head2 move({target_folder => 'Folder 1'})

Moves the message on the server to the named folder.

=cut

sub move {
    my ($self, $o) = @_;

    die 'target_folder not set' unless defined $o->{target_folder};

    return $self->c->model('IMAPClient')->move_message($self->c, {uid => $self->uid, mailbox => $self->mailbox, target_mailbox => $o->{target_folder}});
}

=head2 as_string

Returns the full message source text.

=cut

sub as_string {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->message_as_string($self->c, { uid => $self->uid, mailbox => $self->mailbox } );
}

=head2 main_body_part()

Returns the main body part for using when forwarding/replying the message.

=cut

sub main_body_part {
    my ($self) = @_;

    my $renderable = $self->renderable;
  
    #just return the first text/plain part
    #here we should determine the main 'body part' (text/plain > text/html > ???)
    #FIXME this code does not actually get the first body part. Should use renderable_list here.
    foreach (values %{ $renderable }) {
        my $part = $_;
        if (($part->{is_text} or 0) == 1) {
            return $part->{data};
        }
    }

    return;
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

=head2 body_parts($c)

Returns the body parts of this message as hashref of renderable parts and attachments:
    {
        renderable => {0 => 'Testmessage'},
        attachments => {
            1 => {
                id   => 1,
                type => 'application/binary',
                name => 'testfile',
                data => '...',
                path => '1',
            },
        },
    }

=cut

sub body_parts {
    my ($self, $c) = @_;

    die 'mailbox not set' unless defined $self->mailbox;
    die 'uid not set' unless defined $self->uid;

    my $entity = $self->entity;

    unless ($entity) {
        my $message = $c->model('IMAPClient')->message_as_string($c, { mailbox => $self->mailbox, uid => $self->uid });

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

        if (exists $part_types{$part->effective_type} and not (($part->head->get('content-disposition') or '') =~ /\Aattachment\b/xm)) {
            my $rendered_part = $part_types{$part->effective_type}->($self, $c, { part => $part, id => $id });
            $rendered_part->{id} = $id;
            $body_parts->{$id} = $rendered_part;
        }
        elsif ($part->effective_type =~ m!\Amultipart/!xm) {
            push @parts, $part->parts;
        }
        else {
            $attachments->{$id} = {
                type => $part->effective_type,
                name => ($part->head->mime_attr("content-type.name") or "attachment (".$part->effective_type.")"),
                data => $part->bodyhandle->as_string,
                id   => $id,
                path => ((defined $self->path) ? $self->path."/" : '') . $id,
            } if $part->bodyhandle;
        }

        $id++;
    }

    return { renderable => $body_parts, attachments => $attachments };
}

=head2 _render_text_plain({part => $part})

Internal method rendering a text/plain body part.

=cut

sub _render_text_plain {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part_string = $self->_decode_charset($o);

    my $part = {};
    $part->{data} = Text::Flowed::reformat($part_string);
    $part->{is_text} = 1;

    return $part;
}

=head2 _render_text_calendar({part => $part})

Internal method rendering a text/calendar body part.

=cut

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

=head2 _render_text_html({part => $part})

Internal method rendering a text/html body part.

=cut

sub _render_text_html {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $tidy = HTML::Tidy->new( { output_xhtml => 1, bare => 1, clean => 1, doctype => 'omit', enclose_block_text => 1, show_errors => 0, char_encoding => 'utf8', show_body_only => 1, tidy_mark => 0 } );
    my $scrubber = HTML::Scrubber->new( allow => [ qw/p b strong i u hr br div span table thead tbody tr th td/ ] );

    my @default = (
        0   =>    # default rule, deny all tags
        {
            '*'           => 0, # default rule, deny all attributes
            'href'        => qr{^(?! (?: java)? script )}ixm,
            'src'         => qr{^(?! (?: java)? script )}ixm,
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

=head2 _render_message_rfc822({part => $part})

Internal method rendering a message/rfc822 body part.

=cut

sub _render_message_rfc822 {
    my ($self, $c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part = {};
    
    $part->{data} = CiderWebmail::Message::Forwarded->new(c => $c, entity => $o->{part}->parts(0), mailbox => $self->mailbox, uid => $self->uid, path => (defined $self->path ? "$self->path/" : '') . $o->{id});
    $part->{data}->load_body();

    $part->{is_message} = 1;

    return $part;
}

=head2 _decode_charset({part => $part})

Internal method decoding a body part according to it's stated character set and returning it in Perl's internal encoding.

=cut

sub _decode_charset {
    my ($self, $o) = @_;
    die 'no part set' unless defined $o->{part};

    my $charset = $o->{part}->head->mime_attr("content-type.charset");

    my $part_string;
    unless ($charset and $charset !~ /utf-8/i
        and eval {
            my $converter = Text::Iconv->new($charset, "utf-8");
            $part_string = $converter->convert($o->{part}->bodyhandle->as_string);
        }) {

        warn "unsupported encoding: $charset" if $@;
        $part_string = $o->{part}->bodyhandle->as_string;
    }

    utf8::decode($part_string);

    return $part_string;
}

1;
