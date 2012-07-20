package CiderWebmail::Message;

use Moose;

use CiderWebmail::Part;

use Carp qw/ croak /;

has c               => (is => 'ro', isa => 'Object');
has mailbox         => (is => 'ro', isa => 'Str');
has uid             => (is => 'ro', isa => 'Int');

has root_part       => (is => 'rw', isa => 'Object');
has loaded          => (is => 'rw', isa => 'Int', default => 0);

#we use both part_id's and body_id's because not every part has a body_id but we need a unique identifier for every part
has part_id_to_part => (is => 'rw', isa => 'HashRef', default => sub { {} }); #1.2.3 style part_ids according to the bodystructure
has body_id_to_part => (is => 'rw', isa => 'HashRef', default => sub { {} }); #cid:<bodyid> style URIs in text/html parts

sub BUILD {
    my ($self) = @_;

    $self->create_message_stubs;

    return;
}

sub create_message_stubs {
    my ($self) = @_;

    return if defined $self->root_part;
    my $struct = $self->c->model('IMAPClient')->get_bodystructure({ mailbox => $self->mailbox, uid => $self->uid });
    $struct->bodystructure;

    my $part = CiderWebmail::Part::Root->new({ c => $self->c, root_message => $self, bodystruct => $struct });
    $self->root_part($part);

    return;
}

=head2 get_part_by_part_id({ part_id => '1.2.3' })

takes the part_id of a message part and returns the CiderWebmail::Part
object of a bodypart of this message

=cut

sub get_part_by_part_id {
    my ($self, $o) = @_;

    unless (defined $self->part_id_to_part->{$o->{part_id}}) {
        croak("get_part() failed for part $o->{part_id}");
    }

    return $self->part_id_to_part->{$o->{part_id}};
}


=head2 get_part_by_body_id({ body_id => $body_id })

takes the body_id (cid) of a message part and returns the
CiderWebmail::Part object of a bodypart of this message

=cut

sub get_part_by_body_id {
    my ($self, $o) = @_;

    unless (defined $self->body_id_to_part->{$o->{body_id}}) {
        croak("get_part_by_body_id() failed for body part $o->{body_id}");
    }

    return $self->body_id_to_part->{$o->{body_id}};
}

sub render {
    my ($self) = @_;
    return $self->root_part->render();
}

=head2 get_header($header)

Returns the first value found for the named header

=cut

sub get_header {
    my ($self, $header) = @_;

    return scalar $self->c->model('IMAPClient')->get_headers({ uid => $self->uid, mailbox => $self->mailbox, headers => [$header]});
}

=head2 flags()

returns hashref of IMAP flags for this message

=cut

sub flags {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->get_flags({ uid => $self->uid, mailbox => $self->mailbox });
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

=head2 message_id()

Shortcut for getting the 'Message-ID' header

=cut

sub message_id {
    my ($self) = @_;

    return $self->get_header('Message-ID');
}

=head2 references()

Shortcut for getting the 'References' header

=cut

sub references {
    my ($self) = @_;

    return $self->get_header('References');
}

=head2 mark_read()

Mark the message as read

=cut

sub mark_read {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->mark_read({ uid => $self->uid, mailbox => $self->mailbox });
}

=head2 mark_answered()

Mark the message as answered

=cut

sub mark_answered {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->mark_answered({ uid => $self->uid, mailbox => $self->mailbox });
}


=head2 date()

Returns the 'date' header as datetime object

=cut

sub date {
    my ($self) = @_;

    return $self->get_header('date');
}

=head2 delete()

Deletes the message from the server.

=cut

sub delete {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->delete_messages({ uids => [ $self->uid ], mailbox => $self->mailbox } );
}

=head2 toggle_important()

Toggles the important/flagged IMAP flag of the message.

=cut

sub toggle_important {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->toggle_important({ uid => $self->uid, mailbox => $self->mailbox });
}


=head2 move({target_folder => 'Folder 1'})

Moves the message on the server to the named folder.

=cut

sub move {
    my ($self, $o) = @_;

    croak('target_folder not set') unless defined $o->{target_folder};

    return $self->c->model('IMAPClient')->move_message({uid => $self->uid, mailbox => $self->mailbox, target_mailbox => $o->{target_folder}});
}

=head2 as_string

Returns the full message source text.

=cut

sub as_string {
    my ($self) = @_;

    return $self->c->model('IMAPClient')->message_as_string({ uid => $self->uid, mailbox => $self->mailbox } );
}

1;
