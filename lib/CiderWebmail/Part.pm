package CiderWebmail::Part;

use Moose;
use Petal;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];

use Carp qw/ carp /;

has c           => (is => 'ro', isa => 'Object');
has mailbox     => (is => 'ro', isa => 'Str');
has uid         => (is => 'ro', isa => 'Int');

has entity      => (is => 'ro', isa => 'Object');

has path        => (is => 'ro', isa => 'Str');
has id          => (is => 'ro', isa => 'Int');

has parent_message     => (is => 'ro', isa => 'Object'); #ref to the CiderWebmail::Message object this part is part of

my %renderers = map{ $_->content_type => $_ } __PACKAGE__->plugins();

=head2 body()

returns the body of the part

=cut

sub body {
    my ($self, $o) = @_;

    my $charset = $self->entity->head->mime_attr("content-type.charset");

    return $self->_decode_body({ charset => $charset, body => $self->entity->bodyhandle->as_string });
}

=head2 _decode_body()

attempt a best-effort $charset to utf-8 conversion

=cut

sub _decode_body {
    my ($self, $o) = @_;

    my $part_string;
    unless ($o->{charset} and $o->{charset} !~ /utf-8/ixm
        and eval {
            my $converter = Text::Iconv->new($o->{charset}, "utf-8");
            $part_string = $converter->convert($o->{body});
        }) {

        carp "unsupported encoding: $o->{charset}" if $@;
        $part_string = $o->{body};
    }

    utf8::decode($part_string);

    return $part_string;
}

=head2 type()

returns the MIME Type of the part

=cut

sub type {
    my ($self) = @_;

    return $self->entity->effective_type;
}

=head2 handler()

returns the 'handler' for the part: a CiderWebmail::Part::FooBar object that can be used to ->render the part.

=cut

sub handler {
    my ($self) = @_;
    
    if (defined($renderers{$self->type})) {
        return $renderers{$self->type}->new({ entity => $self->entity, uid => $self->uid, mailbox => $self->mailbox, c => $self->c, parent_message => $self->parent_message, id => $self->id, path => $self->path });
    } else {
        return $self;
    }
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

    my ($type, $subtype) = split('/', $self->type);

    if (defined($content_subtypes->{$self->type})) {
        return $content_subtypes->{$self->type};
    }
    elsif (defined($content_types->{$type})) {
        return $content_types->{$type};
    }
    else {
        return 'generic.png';
    }
}


=head2 subparts()

returns the subparts (MIME::Entity objects) of the current part (in case of multipart/* parts)

=cut

sub subparts {
    my ($self) = @_;

    my @parts = $self->entity->parts;
    if (wantarray) {
        return @parts;
    } else {
        return scalar(@parts);
    }
}

=head2 render()

render a CiderWebmail::Part. just a stub - override in CiderWebmail::Part::FooBar

=cut

sub render {
    my ($self) = @_;

    return;
}

=head2 as_string()

returns the body of the part as a string

=cut

sub as_string {
    my ($self) = @_;

    confess("Part->as_string called with no bodyhandle aviable") unless defined $self->entity->bodyhandle;
    return $self->entity->bodyhandle->as_string;
}

=head2 cid()

returns the Content-ID of the part

=cut

sub cid {
    my ($self) = @_;

    my $cid = ($self->entity->head->get('Content-ID') or '');
    chomp($cid);
    $cid =~ s/[<>]//gxm;

    return $cid;
}


=head2 attachment()

returns true if the part is a attachment (if content-disposition eq 'attachment')

=cut

sub attachment {
    my ($self) = @_;

    if (($self->entity->head->get('content-disposition') or '') =~ /\Aattachment\b/xm) {
        return 1;
    } 

    return;
}

=head2 renderable()

returns true if the part is renderable (just a stub, override in CiderWebmail::Part::FooBar)

=cut

sub renderable {
    return;
}

=head2 message()

returns true if the part is a message (message/rfc822) (just a stub, override in CiderWebmail::Part::FooBar)

=cut

sub message {
    return;
}

=head2 content_type()

returns the content type the CiderWebmail::Part Plugin can handle (just a stub, override in CiderWebmail::Part::FooBar)

=cut

#TODO: stupid name
sub content_type {
    return;
}


=head2 name()

returns the name of the part or "attachment content/type"

=cut

sub name {
    my ($self) = @_;

    return ($self->entity->head->recommended_filename or "attachment (".$self->type.")");
}

=head2 has_body()

returns true if the (body of the) part contains data

=cut

sub has_body {
    my ($self) = @_;

    if (($self->body or '') =~ /\S/xms) {
        return 1;
    }

    return;
}

=head2 uri

returns an http url to access the part

=cut

sub uri {
    my ($self) = @_;

    return $self->c->uri_for('/mailbox/' . $self->c->stash->{folder} . '/' . $self->uid . '/attachment/'.$self->path);
}

1;
