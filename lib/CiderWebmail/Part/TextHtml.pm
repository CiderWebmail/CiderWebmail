package CiderWebmail::Part::TextHtml;

use Moose;

use HTML::Defang qw/ DEFANG_NONE DEFANG_ALWAYS DEFANG_DEFAULT /;
use HTML::Tidy;

use Carp qw/ croak carp /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 1 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );
has defang_media_count  => (is => 'rw', isa => 'Int', default => 0 ); #counter to keep track of how many insecure
                                                                      #elements we removed. if >1 we can inform
                                                                      #the user and ask if they would like to load
                                                                      #them anyway.

=head2 render()

renders a text/html body part.

=cut

sub render {
    my ($self) = @_;

    #https://developer.mozilla.org/en/Security/CSP/Using_Content_Security_Policy
    my $csp = "default-src 'self'";
    $csp   .= "; img-src *" if $self->load_external_media;
    $self->c->response->headers->header('Content-Security-Policy' => $csp);
    $self->c->response->headers->header('X-Content-Security-Policy' => $csp);
    $self->c->response->headers->header('X-WebKit-CSP' => $csp);

    return $self->get_html_body();
}

=head2 uri_render

returns an http url to render the part
overridden here because we need a other uri when loading external media

=cut

sub uri_render {
    my ($self) = @_;

    return $self->c->stash->{uri_folder} . '/' . $self->root_message->uid . '/part/render/' . $self->part_id . ($self->load_external_media ? "?load_external_media=1" : "");
}


sub load_external_media {
    my ($self) = @_;

    return ($self->c->req->param('load_external_media') or 0);
}

sub render_stub {
    my ($self) = @_;

    carp('no part set') unless defined $self->body;

    $self->get_html_body();

    return $self->c->view->render_template({ c => $self->c, template => 'TextHtmlStub.xml', stash => { part => $self } });
}

sub get_html_body {
    my ($self) = @_;
    
    carp('no part set') unless defined $self->body;

    my $tidy = HTML::Tidy->new( { tidy_mark => 0 } );

    my $defang = HTML::Defang->new(
        context => $self, #CiderWebmail::Part::TextHtml object
        fix_mismatched_tags => 1,
        url_callback        => \&_defang_url_callback,
    );

    return $defang->defang($tidy->clean($self->body));
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

        if ($$AttrValR =~ m|^https?://.+|xmi) {
            return DEFANG_NONE if $part->load_external_media;

            #only increment the counter for elements we could display if load_external_media was true
            #this hides the 'show-external-media' message from the user if load_external_media is already
            #true
            $part->defang_media_count($part->defang_media_count + 1);
        }
    }

    if ($lcTag eq 'a') {
        #add target _blank attribute to a tags so they open in a new window/tab
        $AttributeHash->{"target"} = \"_blank";

        #allow URIs in a tags
        return DEFANG_NONE;
    }

    return DEFANG_ALWAYS;
}

1;
