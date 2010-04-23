package HTML::Cleaner;
use warnings;
use strict;

use base qw( HTML::Parser );

use HTML::Tidy;
use HTML::Entities qw/ encode_entities decode_entities /;

=head2 process({ input => $html_string })

processes a HTML string, returns clean XHTML

=cut

sub process {
    my ($self, $o) = @_;

    my $tidy = HTML::Tidy->new( { output_xhtml => 1, bare => 1, doctype => 'omit', enclose_block_text => 1, show_errors => 0, char_encoding => 'utf8', show_body_only => 1, tidy_mark => 0 } );

    $self->{_output} = '';
    $self->{_state} = {};
    $self->{_mime_cids} = $o->{mime_cids};

    $self->handler(start => "_start_handler", 'self, tagname, attr');
    $self->handler(end => "_end_handler", 'self, tagname');
    $self->handler(text => "_text_handler", 'self, text, is_cdata');

    $self->parse($tidy->clean($o->{input}));

    return $self->{output};
}

my $tags = {
    table   => { allowed => 1, start_filter => \&_filter_tag_table  },
    tr      => { allowed => 1, attributes => { rowspan => { allowed => 1 } }},
    td      => { allowed => 1, start_filter => \&_filter_tag_td, attributes => { colspan => { allowed => 1 } }},
    th      => { allowed => 1, attributes => { colspan => { allowed => 1 } }},

    p       => { allowed => 1 },

    br      => { allowed => 1 },

    style   => { allowed => 1, start_filter => \&_filter_tag_style, end_filter => \&_filter_discard },

    img     => { allowed => 1, start_filter => \&_filter_tag_img, end_filter => \&_filter_discard, attributes => { src => { allowed => 1}, alt => { allowed => 1, add => 1 } } },

    font    => { allowed => 1, start_filter => \&_filter_tag_font, end_filter => \&_filter_tag_font_end, attributes => { color => { filter => \&_filter_font_color } } },
    b       => { allowed => 1, start_filter => \&_filter_tag_b, end_filter => \&_filter_tag_b_end },

    span    => { allowed => 1, },
    center  => { allowed => 1, },

    a       => { allowed => 1, attributes => { href => { allowed => 1 } } },

    div     => { allowed => 1 },
};

=head2 _start_handler

internal method for processing html open tags

=cut

sub _start_handler {
    my ($self, $tagname, $attr) = @_;
    return unless (($tags->{$tagname}->{allowed} or 0  ) == 1);

    if ($tags->{$tagname}->{start_filter}) {
        $self->{output} .= $tags->{$tagname}->{start_filter}->($self, { tagname => $tagname, attr => $attr });
    } else {
        $self->{output} .= "<$tagname";

        $self->{output} .= $self->_handle_attributes({ tagname => $tagname, attr => $attr });

        $self->{output} .= " /" if $attr->{'/'};
        $self->{output} .= ">";
    }

    return;
}

=head2 _end_handler

internal method for processing html end tags

=cut

sub _end_handler {
    my ($self, $tagname) = @_;
    return unless (($tags->{$tagname}->{allowed} or 0  ) == 1);

    if ($tags->{$tagname}->{end_filter}) {
        $self->{output} .= $tags->{$tagname}->{end_filter}->($self, { tagname => $tagname });
    } else {
        $self->{output} .= "</$tagname>";
    }

    return;
}

=head2 _text_handler

internal method for processing text events

=cut

sub _text_handler {
    my ($self, $text, $cdata) = @_;

    if ($self->{_state}->{text_filter}) {
        $self->{output} .= $self->{_state}->{text_filter}->($self, { text => $text });
        $self->{_state}->{text_filter} = undef;
    } else {
        $self->{output} .= $text unless $cdata;
    }

    return;
}

=head2 _handle_attributes()

internal method for processing attributes of html tags

=cut

sub _handle_attributes {
    my ($self, $o) = @_;

    $tags->{$o->{tagname}}->{attributes}->{style}->{filter} = \&_filter_style;

    while(my ($key, $value) = each(%{ $tags->{$o->{tagname}}->{attributes} })) {
        if (($value->{add} or 0) == 1) {
            $o->{attr}->{$key} = 'none' unless(defined($o->{attr}->{$key}));
        }
    }

    my $output = '';
    while(my ($key, $value) = each(%{ $o->{attr} })) {
        $value = encode_entities(decode_entities($value));

        if (defined($tags->{$o->{tagname}}->{attributes}->{$key}->{filter})) {
            $output .= $tags->{$o->{tagname}}->{attributes}->{$key}->{filter}->($self, { tagname => $o->{tagname}, value => $value });
        } else {
            $output .= " $key=\"$value\"" if (($tags->{$o->{tagname}}->{attributes}->{$key}->{allowed} or 0) == 1);
        }
    }

    return $output;
}

=head2 _filter_discard

html tag filter: discards the tag

=cut

sub _filter_discard {
    my ($self, $o) = @_;
    return '';
}

=head2 _filter_tag_style

html tag filter: processes style tags

=cut

sub _filter_tag_style {
    my ($self, $o) = @_;

    $self->{_state}->{text_filter} = \&_filter_tag_style_text;

    return '';
}

=head2 _filter_tag_style_text

html tag filter: processes content of style tags

=cut

sub _filter_tag_style_text {
    my ($self, $o) = @_;

    return '';
}

=head2 _filter_tag_img

html tag filter: processes img tags

=cut

sub _filter_tag_img {
    my ($self, $o) = @_;

    my $output = "<img";

    if (($o->{attr}->{border} or '') =~ m/^(0|1)$/xm) {
        $o->{attr}->{style} .= " border: $1px;"
    };

    if (($o->{attr}->{src} or '') =~ m/^cid:(.*)$/xm) {
        $o->{attr}->{src} = $self->{_mime_cids}->{$1};
    }

    $output .= $self->_handle_attributes({ tagname => 'img', attr => $o->{attr} });

    $output .= " /" if $o->{attr}->{'/'};
    $output .= ">";
    return $output;
}

=head2 _filter_tag_font

html tag filter: processes font tags, converts them to span tags

=cut

sub _filter_tag_font {
    my ($self, $o) = @_;

    my $output = "<span";

    if ((lc($o->{attr}->{color}) or '') =~ m/([a-f]+|\#[\da-f]{3,6})/xm) {
        $o->{attr}->{style} .= "color: $1;";
    }

    $output .= $self->_handle_attributes({ tagname => 'span', attr => $o->{attr} });

    $output .= ">";

    return $output;
}

=head2 _filter_tag_b

html tag filter: processes b tags, converts them to span tags

=cut

sub _filter_tag_b {
    my ($self, $o) = @_;

    return "<span style='font-weight: bold;'>";
}


=head2 _filter_tag_table

html tag filter: processes table tags

=cut

sub _filter_tag_table {
    my ($self, $o) = @_;

    my $output = "<table";

    if ((lc($o->{attr}->{width}) or '') =~ m/^(\d{1,4})$/xm) {
        $o->{attr}->{style} .= " width: $1px;";
    }

    if ((lc($o->{attr}->{align}) or '') =~ m/^(left|center|right)$/xm) {
        $o->{attr}->{style} .= " text-align: $1;";
    }

    $output .= $self->_handle_attributes({ tagname => 'table', attr => $o->{attr} });

    $output .= ">";

    return $output;
}

=head2 _filter_tag_td

html tag filter: processes table data tags

=cut

sub _filter_tag_td {
    my ($self, $o) = @_;

    my $output = "<td";

    if ((lc($o->{attr}->{width}) or '') =~ m/^(\d{1,4})$/xm) {
        $o->{attr}->{style} .= "width: $1px;";
    }

    $output .= $self->_handle_attributes({ tagname => 'td', attr => $o->{attr} });

    $output .= ">";

    return $output;
}

=head2 _filter_tag_font_end

html tag filter: processes font end tag, converts to span tag

=cut

sub _filter_tag_font_end {
    my ($self, $o) = @_;

    return "</span>";
}

=head2 _filter_tag_b_end

html tag filter: processes b end tag, converts to span tag

=cut

sub _filter_tag_b_end {
    my ($self, $o) = @_;

    return "</span>";
}


#filter for attributes
my $default_styles = {
    font => { allowed => 1},
    text_decoration => { allowed => 1},
    color => { allowed => 1 },
};

my $styles = {
    img => { %$default_styles, border => { allowed => 1} },
    span => { %$default_styles },
    table => { %$default_styles, width => { allowed => 1 }, text_align => { allowed => 1 }, },
    td => { %$default_styles, width => { allowed => 1} },
    a => { %$default_styles },
};

=head2 _filter_style

style filter: processes CSS

=cut

#TODO this is probably to crude
sub _filter_style {
    my ($self, $o) = @_;

    my $output = '';

    my @css_attr = split(/;/xm, ($o->{value} or ''));

    foreach(@css_attr) {
        my ($key, $value) = split(/:/xm, $_);
        $key =~ s/[^a-z]//gixm;
        $output .= "$key: $value;" if (defined($styles->{$o->{tagname}}->{$key}) && ($styles->{$o->{tagname}}->{$key}->{allowed} == 1));
    }

    return ' style="'.$output.'"';
}

1;
