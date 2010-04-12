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
    unless ($charset and $charset !~ /utf-8/i
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

sub type {
    my ($self) = @_;

    return $self->entity->effective_type;
}

sub handler {
    my ($self) = @_;
    
    if (defined($renderers{$self->type})) {
        return $renderers{$self->type}->new({ entity => $self->entity, uid => $self->uid, mailbox => $self->mailbox, c => $self->c, id => $self->id, path => $self->path });
    } else {
        return $self;
    }
}

sub subparts {
    my ($self) = @_;

    my @parts = $self->entity->parts;
    if (wantarray) {
        return @parts;
    } else {
        return scalar(@parts);
    }
}

sub render {
    my ($self) = @_;

    return;
}

sub as_string {
    my ($self) = @_;

    return $self->entity->bodyhandle->as_string;
}

sub attachment {
    my ($self) = @_;

    if (($self->entity->head->get('content-disposition') or '') =~ /\Aattachment\b/xm) {
        return 1;
    } 

    return;
}

sub renderable {
    return;
}

sub message {
    return;
}

sub name {
    my ($self) = @_;

    return ($self->entity->head->recommended_filename or "attachment (".$self->type.")");
}

1;
