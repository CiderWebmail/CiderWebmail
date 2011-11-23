package CiderWebmail::Part::Root;

use Moose;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_by_default   => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 1 );
has attachment          => (is => 'rw', isa => 'Bool', default => 0 );

has parent_message => (is => 'ro', required => 0, isa => 'Object'); #ref to the CiderWebmail::Part::(Root|RFC822) object this part is part of

#override load_children() here because the ROOT part might contain have a part that is not a child (for example a single text/plain part without a multipart/* parent).
#TODO cleanup
sub load_children {
    my ($self) = @_;

    my $count = 0;
    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        push(@{ $self->{children} }, $part) if $part;
        $self->root_message->parts->{$part->id} = $part;
        $count++;
    }

    unless ($count > 0) {
        my $part = $self->handler({ bodystruct => $self->bodystruct });
        push(@{ $self->{children} }, $part);
        $self->root_message->parts->{$part->id} = $part;
    }

    $self->root_message->parts->{root} = $self;
}

sub type {
    return 'x-ciderwebmail/rootmessage';
}

sub id {
    return 'root';
}

=head2 render()

renders a message/rfc822 body part.

=cut

sub render {
    my ($self) = @_;

    return $self->c->view->render_template({ c => $self->c, template => 'RFC822.xml', stash => { message => $self } });
}

sub subject {
    my ($self) = @_;

    return $self->root_message->subject;
}

sub date {
    my ($self) = @_;
    return $self->root_message->date;
}

sub from {
    my ($self) = @_;
    return $self->root_message->from;
}

sub reply_to {
    my ($self) = @_;
    return $self->root_message->reply_to;
}

sub to {
    my ($self) = @_;
    return $self->root_message->to;
}

sub cc {
    my ($self) = @_;
    return $self->root_message->cc;
}

sub bcc {
    my ($self) = @_;
    return $self->root_message->bcc;
}

sub body {
    my ($self) = @_;
    my $body = $self->c->model('IMAPClient')->message_as_string($self->c, { mailbox => $self->mailbox, uid => $self->uid });

    return $self->_decode_body({ charset => $self->charset, body => $body });
}

sub message_id {
    my ($self) = @_;

    return $self->root_message->message_id;
}

sub references {
    my ($self) = @_;

    return $self->root_message->references;
}

sub mark_answered {
    my ($self) = @_;

    $self->root_message->mark_answered;
}

=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'x-ciderwebmail/rootmessage';
}

1;
