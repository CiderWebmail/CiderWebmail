package CiderWebmail::Message;

use Moose;

use CiderWebmail::Part;

has c           => (is => 'ro', isa => 'Object');
has mailbox     => (is => 'ro', isa => 'Str');
has uid         => (is => 'ro', isa => 'Int');

has renderable  => (is => 'rw', isa => 'ArrayRef');
has attachments => (is => 'rw', isa => 'ArrayRef');
has all_parts   => (is => 'rw', isa => 'ArrayRef');
has cid_to_part => (is => 'rw', isa => 'HashRef');

has loaded      => (is => 'rw');

has entity      => (is => 'ro', isa => 'Object');
has path        => (is => 'rw', isa => 'Str');

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
    $self->all_parts($body_parts->{all_parts});
    $self->all_parts($body_parts->{all_parts});
    $self->cid_to_part($body_parts->{cid_to_part});

    return;
}

before qw(renderable attachments all_parts get_embedded_message) => sub {
    my ($self) = @_;
    $self->load_body();
};

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

    #just return the first text/plain part
    #here we should determine the main 'body part' (text/plain > text/html > ???)
    #FIXME this code does not actually get the first body part. Should use renderable_list here.
    foreach (@{ $self->renderable }) {
        my $part = $_;
        if ( ($part->content_type or '') eq 'text/plain') {
            return $part->body;
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

    foreach (@path) {
        $body = $body->all_parts->[$_]->render;
    }

    return $body;
}

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
 
    my $renderable  = []; #body parts we render (text/plain, text/html, etc)
    my $attachments = []; #body parts we don't render (everything else)
    my $all_parts   = []; #all body parts
    my $cid_to_part = {}; #Content-ID to CiderWebmail::Part mapping

    my $id = 0;
    while (@parts) {
        my $part = shift @parts;

        $self->_process_body_part({ renderable => $renderable, attachments => $attachments, all_parts => $all_parts, cid_to_part => $cid_to_part, entity => $part, id => \$id });
    }

    return { renderable => $renderable, attachments => $attachments, all_parts => $all_parts, cid_to_part => $cid_to_part };
}

sub _process_body_part {
    my ($self, $o) = @_;

    my $id = ${ $o->{id} };

    my $part = CiderWebmail::Part->new({ c => $self->c, entity => $o->{entity}, uid => $self->uid, mailbox => $self->mailbox, parent_message => $self, id => $id, path => (defined $self->path ? $self->path."/" : '').$id })->handler;

    if ($part->attachment) {
        push(@{ $o->{attachments} }, $part);
    }
    elsif ($part->renderable or $part->message) {
        push(@{ $o->{renderable} }, $part);
    }
    elsif ($part->subparts) {
        foreach($part->subparts) {
            $self->_process_body_part({ renderable => $o->{renderable}, attachments => $o->{attachments}, all_parts => $o->{all_parts}, cid_to_part => $o->{cid_to_part}, entity => $_, id => $o->{id} });
        }
    }
    
    push(@{ $o->{all_parts} }, $part);

    if($part->cid) {
        $o->{cid_to_part}->{$part->cid} = $part->path;
    }

    ${ $o->{id} }++;

    return;
}

1;
