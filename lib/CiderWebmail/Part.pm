package CiderWebmail::Part;

use Moose;
use Petal;
use MIME::Base64;
use MIME::QuotedPrint;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];

use Carp qw/ carp cluck /;

has c              => (is => 'ro', isa => 'Object');

has root_message   => (is => 'ro', required => 1, isa => 'Object'); #ref to the CiderWebmail::Message object this part is part of
has parent_message => (is => 'ro', required => 1, isa => 'Object'); #ref to the CiderWebmail::Part::(Root|RFC822) object this part is part of

has bodystruct     => (is => 'ro', isa => 'Object'); #Mail::IMAPClient::BodyStructure Object of this part

has children       => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

has renderable          => (is => 'rw', isa => 'Bool', default => 0 ); #override me!
has render_by_default   => (is => 'rw', isa => 'Bool', default => 0 ); #override me!
has message             => (is => 'rw', isa => 'Bool', default => 0 ); #override me!
has attachment          => (is => 'rw', isa => 'Bool', default => sub {
    my ($self) = @_;

    return 0 unless defined $self->bodystruct->{bodydisp};
    return 0 unless (ref($self->bodystruct->{bodydisp}) eq 'HASH');
    return 1 if defined $self->bodystruct->{bodydisp}->{attachment};
    return 0;
},);

my %renderers = map{ $_->supported_type => $_ } __PACKAGE__->plugins();

sub BUILD {
    my $self = shift;

    $self->load_children();

    return;
}

sub load_children {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodystructure};

    foreach(@{ $self->bodystruct->{bodystructure} }) {
        my $part = $self->handler({ bodystruct => $_ });

        push(@{ $self->{children} }, $part) if $part;
        $self->root_message->parts->{$part->id} = $part;
    }

    return;
}

=head2 main_body_part()

Returns the main body part for using when forwarding/replying the message.

=cut

sub main_body_part {
    my ($self) = @_;

    foreach (@{ $self->children }) {
        my $part = $_;
        if ( ($part->content_type or '') eq 'text/plain') {
            return $part;
        }
    }

    return CiderWebmail::Part::Dummy->new({ root_message => $self->root_message, parent_message => $self->get_parent_message });
}

=head2 body()

returns the body of the part
unless body({ raw => 1}) is specified converting the body to utf-8 will be attempted

=cut

sub body {
    my ($self, $o) = @_;

    my $body = $self->c->model('IMAPClient')->bodypart_as_string($self->c, { mailbox => $self->mailbox, uid => $self->uid, part => $self->id });

    if (defined($self->bodystruct->{bodyenc}) and (lc($self->bodystruct->{bodyenc}) eq 'base64')) {
        $body = decode_base64($body);
    }

    if (defined($self->bodystruct->{bodyenc}) and (lc($self->bodystruct->{bodyenc}) eq 'quoted-printable')) {
        $body = decode_qp($body);
    }


    return (defined($o->{raw}) ? $body : $self->_decode_body({ body => $body }));
}

sub header {
    my ($self) = @_;

    croak("attempted to call header() on a not-message CiderWebmail::Part object. this is a ".$self->content_type." part") unless $self->message;

    my $body = $self->body({ raw => 1 });
    my $email = Email::Simple->new($body);
    return $email->header_obj->as_string;
}


sub mailbox {
    my ($self) = @_;

    return $self->root_message->mailbox;
}

sub uid {
    my ($self) = @_;

    return $self->root_message->uid;
}

=head2 _decode_body()

attempt a best-effort $charset to utf-8 conversion

=cut

sub _decode_body {
    my ($self, $o) = @_;

    my $part_string;
    unless ($self->charset and $self->charset !~ /utf-8/ixm
        and eval {
            my $converter = Text::Iconv->new($self->charset, "utf-8");
            $part_string = $converter->convert($o->{body});
        }) {

        carp "unsupported encoding: ".$self->charset if $@;
        $part_string = $o->{body};
    }

    utf8::decode($part_string);

    return $part_string;
}

=head2 id()

returns the ID of the part

=cut

sub id {
    my ($self) = @_;

    return $self->bodystruct->id;
}

sub charset {
    my ($self) = @_;

    return unless ((defined $self->bodystruct->bodyparms) and ($self->bodystruct->bodyparms ne 'NIL'));
    return $self->bodystruct->bodyparms->{charset};
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


=head2 handler()

returns a CiderWebmail::Part::FooBar object for the specified part

=cut

sub handler {
    my ($self, $o) = @_;

    confess unless $o->{bodystruct};

    my $type = lc($o->{bodystruct}->bodytype.'/'.$o->{bodystruct}->bodysubtype);

    if (defined($renderers{$type})) {
        return $renderers{$type}->new({ c => $self->c, root_message => $self->root_message, bodystruct => $o->{bodystruct}, parent_message => $self->get_parent_message });
    } else {
        return $renderers{'x-ciderwebmail/attachment'}->new({ c => $self->c, root_message => $self->root_message, bodystruct => $o->{bodystruct}, parent_message => $self->get_parent_message });
    }
}

sub get_parent_message {
    my ($self) = @_;

    #if this part is a message (true for Part::RFC822 and Part::Root) use $self for parent_message
    #otherwise pass the last message part (RFC822 or Root) along
    return ( $self->message ? $self : $self->parent_message );
}

=head2 icon() {

returns the name of a icon representing the content type fo the part

=cut

#mime type to icon mapping
my $content_types = {
    audio => 'audio.png',
    text  => 'text.png',
    video => 'movie.png',
    image => 'image2.png',
};

my $content_subtypes = {
    'application/pdf' => 'pdf.png',
};

sub icon {
    my ($self) = @_;

    my ($type, $subtype) = split('/', $self->content_type);

    if (defined($content_subtypes->{$self->content_type})) {
        return $content_subtypes->{$self->content_type};
    }
    elsif (defined($content_types->{$type})) {
        return $content_types->{$type};
    }
    else {
        return 'generic.png';
    }
}

=head2 render()

render a CiderWebmail::Part. just a stub - override in CiderWebmail::Part::FooBar

=cut

sub render {
    my ($self) = @_;

    confess "[FATAL] CiderWebmail::Part->render() called but was not overridden by anything!";
}

=head2 cid()

returns the Content-ID of the part

=cut

sub cid {
    my ($self) = @_;

    cluck("cid() not implemented");

    my $cid = ($self->entity->head->get('Content-ID') or '');
    chomp($cid);
    $cid =~ s/[<>]//gxm;

    return $cid;
}


=head2 content_type()

returns the content type of the CiderWebmail::Part

=cut

sub content_type {
    my ($self) = @_;

    return lc($self->bodystruct->bodytype.'/'.$self->bodystruct->bodysubtype);
}


=head2 name()

returns the name of the part or "(attachment|part) content/type"

=cut

sub name {
    my ($self) = @_;

    return "part (".$self->content_type.")" unless ((defined $self->bodystruct->bodydisp) and ($self->bodystruct->bodydisp ne 'NIL'));

    #TODO filter filenmae
    return $self->bodystruct->bodydisp->{attachment}->{filename} if ((defined $self->bodystruct->bodydisp->{attachment}->{filename}) and ($self->bodystruct->bodydisp->{attachment}->{filename} ne 'NIL'));
    return "attachment (".$self->content_type.")" if defined $self->bodystruct->bodydisp->{attachment};
    return "part (".$self->content_type.")";
}

=head2 uri_download

returns an http url to access the part

=cut

sub uri_download {
    my ($self) = @_;

    return $self->c->stash->{uri_folder} . '/' . $self->root_message->uid . '/part/download/' . $self->id;
}

=head2 uri_render

returns an http url to render the part

=cut

sub uri_render {
    my ($self) = @_;

    return $self->c->stash->{uri_folder} . '/' . $self->root_message->uid . '/part/render/' . $self->id;
}


1;
