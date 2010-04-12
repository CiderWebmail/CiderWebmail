package CiderWebmail::Part::TextHtml;

use Moose;
use HTML::Tidy;
use HTML::Scrubber;

extends 'CiderWebmail::Part';

=head2 render()

Internal method rendering a text/plain body part.

=cut

sub render {
    my ($self) = @_;

    die 'no part set' unless defined $self->body;

    my $tidy = HTML::Tidy->new( { output_xhtml => 1, bare => 1, clean => 1, doctype => 'omit', enclose_block_text => 1, show_errors => 0, char_encoding => 'utf8', show_body_only => 1, tidy_mark => 0 } );
    my $scrubber = HTML::Scrubber->new( allow => [ qw/p b strong i u hr br div span table thead tbody tr th td/ ] );

    my @default = (
        0 => # default rule, deny all tags
        {
            '*' => 0, # default rule, deny all attributes
            'href' => qr{^(?! (?: java)? script )}ixm,
            'src' => qr{^(?! (?: java)? script )}ixm,
            'class' => 1,
            'style' => 1,
        }
    );
    
    $scrubber->default( @default );

    my $content = $scrubber->scrub($self->body);
    $content = $tidy->clean($content);

    return $self->c->view->render_template({ c => $self->c, template => 'TextHtml.xml', stash => { part_content => $content } });
}

sub content_type {
    return 'text/html';
}

sub is_html {
    return 1;
}

sub renderable {
    return 1;
}

1;
