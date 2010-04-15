package CiderWebmail::Part;

use Moose;
use Petal;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];

has c           => (is => 'ro', isa => 'Object');
has mailbox     => (is => 'ro', isa => 'Str');
has uid         => (is => 'ro', isa => 'Int');

has entity      => (is => 'ro', isa => 'Object');

has path        => (is => 'ro', isa => 'Str');
has id          => (is => 'ro', isa => 'Int');

my %renderers = map{ $_->content_type => $_ } __PACKAGE__->plugins();

=head2 body()

returns the body of the part

=cut

sub body {
    my ($self, $o) = @_;

    my $charset = $self->entity->head->mime_attr("content-type.charset");

    my $part_string;
    unless ($charset and $charset !~ /utf-8/ixm
        and eval {
            my $converter = Text::Iconv->new($charset, "utf-8");
            $part_string = $converter->convert($self->entity->bodyhandle->as_string);
        }) {

        warn "unsupported encoding: $charset" if $@;
        $part_string = $self->entity->bodyhandle->as_string;
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
        return $renderers{$self->type}->new({ entity => $self->entity, uid => $self->uid, mailbox => $self->mailbox, c => $self->c, id => $self->id, path => $self->path });
    } else {
        return $self;
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

    return $self->entity->bodyhandle->as_string;
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

1;
