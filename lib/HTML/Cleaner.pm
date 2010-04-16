package HTML::Cleaner;

use Moose;

use HTML::Tidy;
use HTML::Scrubber;

has input => ( is => 'ro', isa => 'Str' );

=head2 process()

processes the input, returnes clean XHTML

=cut

sub process {
    my ($self) = @_;

    die unless $self->input;

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

    my $content = $scrubber->scrub($self->input);
    return $tidy->clean($content);
}

1;
