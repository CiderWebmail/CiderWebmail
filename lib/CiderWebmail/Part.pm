package CiderWebmail::Part;

use Moose;
use Petal;
use MIME::Base64;
use MIME::QuotedPrint;
use CiderWebmail::Util qw/ decode_mime_words /;
use CiderWebmail::MIMEIcons;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];

use Carp qw/ carp cluck /;

has c              => (is => 'ro', isa => 'Object');

has root_message   => (is => 'ro', required => 1, isa => 'Object'); #ref to the CiderWebmail::Message object this part is part of
has parent_message => (is => 'ro', required => 1, isa => 'Object'); #ref to the CiderWebmail::Part::(Root|RFC822) object this part is part of

has bodystruct     => (is => 'ro', isa => 'Object'); #Mail::IMAPClient::BodyStructure Object of this part

has children       => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

has renderable          => (is => 'rw', isa => 'Bool', default => 0 ); #override me!

#stubs are used to render things that get fetched later (like images that get fetched by clicking on a [+] symbol or iframes for html rendering
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 1 ); #override me! 

has message             => (is => 'rw', isa => 'Bool', default => 0 ); #override me!
has attachment          => (is => 'rw', isa => 'Bool', default => sub {
    my ($self) = @_;

    return 0 unless defined $self->bodystruct;
    return 1 unless defined $self->bodystruct->{bodydisp};
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
        $self->root_message->part_id_to_part->{$part->part_id} = $part;
        if (defined $part->body_id) { $self->root_message->body_id_to_part->{$part->body_id} = $part; }
    }

    return;
}

=head2 main_body_part()

Returns the main body part for using when forwarding/replying the message.

=cut

sub main_body_part {
    my ($self) = @_;

    my @to_check = @{ $self->children };

    foreach (@to_check) {
        my $part = $_;
        if ( ($part->content_type or '') eq 'text/plain') {
            return $part;
        }

        if ($part->children) {
            push(@to_check, @{ $part->children });
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

    my $body = $self->c->model('IMAPClient')->bodypart_as_string({ mailbox => $self->mailbox, uid => $self->uid, part => $self->part_id });

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

        carp "unable to convert ".$self->charset." to utf-8 using Text::Iconv: $!" if $@;
        $part_string = $o->{body};
    }

    utf8::decode($part_string);

    return $part_string;
}

=head2 part_id()

returns the part_id of the part

=cut

sub part_id {
    my ($self) = @_;

    return $self->bodystruct->id;
}

=head2 body_id()

returns the body_id of the part or undef

=cut

sub body_id {
    my ($self) = @_;

    return unless defined $self->bodystruct->{bodyid};
    return unless ($self->bodystruct->{bodyid} ne 'NIL');

    my $body_id = $self->bodystruct->{bodyid};
    $body_id =~ s/^\<//xm;
    $body_id =~ s/\>$//xm;

    return $body_id;
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

sub icon {
    my ($self) = @_;

    return CiderWebmail::MIMEIcons::get_mime_icon($self->content_type);
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

sub display_name {
    my ($self) = @_;

    #if we have a file name use this
    return $self->file_name if defined $self->file_name;

    #we don't have a file name but it's an attachment - indicate this and show the content type
    return "attachment (".$self->content_type.")" if $self->is_attachment;

    #we don't have a file name and it's not some kind of attachment
    return "part (".$self->content_type.")";
}

=head2 file_name()

returns a best-guess file_name if one was supplied or undef

=cut

sub file_name {
    my ($self) = @_;

    my $bodydisp = $self->bodydisp;
    my $bodyparms = $self->bodyparms;

    if ($self->is_attachment) {
        return decode_mime_words({ data => $bodydisp->{attachment}->{filename} }) if ((defined $bodydisp->{attachment}->{filename}) and ($bodydisp->{attachment}->{filename} ne 'NIL'));
    }

    if ((defined $bodyparms) and (defined $bodyparms->{name}) and ($bodyparms->{name} ne 'NIL')) {
        return decode_mime_words({ data => $bodyparms->{name} }) if ($bodyparms->{name} =~ m/.*\..*/xm);   #name does not have to be a filename. if we want
                                                                                                                   #to treat it as such it should at least resemble 
                                                                                                                   #something like name.extension
    }

    return;
}

=head2 is_attachment()

returns true if the body disposition indicates it is an attachment

=cut

sub is_attachment {
    my ($self) = @_;

    return unless defined $self->bodydisp;
    return 'yep' if ((defined $self->bodydisp->{attachment}) and ($self->bodydisp->{attachment} ne 'NIL'));
    return;
};


=head2 bodydisp()

returnes the body disposition hash (if it exists) or undef

=cut

sub bodydisp {
    my ($self) = @_;

    return unless ((defined $self->bodystruct) and ($self->bodystruct ne 'NIL'));
    return unless ((defined $self->bodystruct->bodydisp) and ($self->bodystruct->bodydisp ne 'NIL'));
    return $self->bodystruct->bodydisp;
}

=head2 bodyparms()

returnes the bodyparms hash (if it exists) or undef

=cut

sub bodyparms {
    my ($self) = @_;

    return unless ((defined $self->bodystruct) and ($self->bodystruct ne 'NIL'));
    return unless ((defined $self->bodystruct->bodyparms) and ($self->bodystruct->bodyparms ne 'NIL'));
    return $self->bodystruct->bodyparms;
}


=head2 uri_download

returns an http url to access the part

=cut

sub uri_download {
    my ($self) = @_;

    return $self->c->stash->{uri_folder} . '/' . $self->root_message->uid . '/part/download/' . $self->part_id;
}

=head2 uri_render

returns an http url to render the part

=cut

sub uri_render {
    my ($self) = @_;

    return $self->c->stash->{uri_folder} . '/' . $self->root_message->uid . '/part/render/' . $self->part_id;
}

=head2 is_root_part

returns true if this part is the root part (RFC822 message)

=cut

sub is_root_part {
    my ($self) = @_;

    return ($self->root_message->root_part eq $self);
}


1;
