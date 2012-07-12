package CiderWebmail::Part::TextHtml;

use Moose;

use HTML::Defang qw/ DEFANG_NONE DEFANG_ALWAYS DEFANG_DEFAULT /;
use HTML::Tidy;

use Carp qw/ croak carp /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

=head2 render()

renders a text/html body part.

=cut

sub render {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    my $tidy = HTML::Tidy->new( { tidy_mark => 0 } );

    my $defang = HTML::Defang->new(
        context => $self, #CiderWebmail::Part::TextHtml object
        fix_mismatched_tags => 1,
        url_callback        => \&_defang_url_callback,
    );

    #https://developer.mozilla.org/en/Security/CSP/Using_Content_Security_Policy
    $self->c->response->headers->header('X-Content-Security-Policy' => "default-src 'self'");

    return $defang->defang($tidy->clean($self->body));
}

sub render_stub {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    return $self->c->view->render_template({ c => $self->c, template => 'TextHtmlStub.xml', stash => { part => $self } });
}

=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'text/html';
}

#internals for HTML::Defang follow
sub _defang_url_callback {
    #part is the CiderWebmail::Part::TextHtml object
    my ($part, $Defang, $lcTag, $lcAttrKey, $AttrValR, $AttributeHash, $HtmlR) = @_;

    if ($lcTag eq 'img') {
        #TODO maybe allow the user select if they want to include external images - right now we only allow images contained in the e-mail
        if ($$AttrValR =~ m/^cid:(.*)$/xmi) {
            if ($part->root_message->get_part_by_body_id({ body_id => $1 })) {
                $$AttrValR = $part->root_message->get_part_by_body_id({ body_id => $1 })->uri_download;

                #we found the bodypart and rewrote it to our download_uri, whitelist this src attribute otherwise Defang would remove it anyway
                return DEFANG_NONE;
            }
        }
    }

    return DEFANG_ALWAYS;
}

1;
