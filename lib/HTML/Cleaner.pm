package HTML::Cleaner;

use base qw( HTML::Parser );

use HTML::Tidy;

sub process {
    my ($self, $o) = @_;

    my $tidy = HTML::Tidy->new( { output_xhtml => 1, bare => 1, doctype => 'omit', enclose_block_text => 1, show_errors => 0, char_encoding => 'utf8', show_body_only => 1, tidy_mark => 0 } );

    $self->{_output} = '';
    $self->{_state} = {};

    $self->handler(start => "_start_handler", 'self, tagname, attr');
    $self->handler(end => "_end_handler", 'self, tagname');
    $self->handler(text => "_text_handler", 'self, text');


    $self->parse($tidy->clean($o->{input}));

    open(IN, '>/tmp/in.html');
    print IN $o->{input};
    close(IN);


    open(OUT, '>/tmp/out.xhtml');
    print OUT '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';
    print OUT "<html xmlns='http://www.w3.org/1999/xhtml'><head><title>foo</title></head><body>";
    print OUT $self->{output};
    print OUT "</body></html>";
    close(OUT);

    return $self->{output};
}

my $tags = {
    table   => { start_filter => \&_filter_tag_table  },
    tr      => { attributes => { rowspan => {} }},
    td      => { attributes => { colspan => {} }},

    p       => {},

    style   => { start_filter => \&_filter_tag_style, end_filter => \&_filter_discard },

    img     => { start_filter => \&_filter_tag_img, end_filter => \&_filter_discard, attributes => { src => {}, alt => {} } },

    font    => { start_filter => \&_filter_tag_font, end_filter => \&_filter_tag_font_end, attributes => { color => { filter => \&_filter_font_color } } },
    span    => {},

    a       => { attributes => { href => {} } },

    div     => {},
};

sub _start_handler {
    my ($self, $tagname, $attr) = @_;
    return unless $tags->{$tagname};

    if ($tags->{$tagname}->{start_filter}) {
        $self->{output} .= $tags->{$tagname}->{start_filter}->($self, { tagname => $tagname, attr => $attr });
    } else {
        $self->{output} .= "<$tagname";

        $self->{output} .= $self->_handle_attributes({ tagname => $tagname, attr => $attr });

        $self->{output} .= " /" if $attr->{'/'};
        $self->{output} .= ">";
    }
}

sub _end_handler {
    my ($self, $tagname) = @_;
    return unless $tags->{$tagname};

    if ($tags->{$tagname}->{end_filter}) {
        $self->{output} .= $tags->{$tagname}->{end_filter}->($self, { tagname => $tagname, attr => $attr });
    } else {
        $self->{output} .= "</$tagname>";
    }
}

sub _text_handler {
    my ($self, $text) = @_;

    if ($self->{_state}->{text_filter}) {
        $self->{output} .= $self->{_state}->{text_filter}->($self, { text => $text });
        $self->{_state}->{text_filter} = undef;
    } else {
        $self->{output} .= $text;
    }
}

sub _handle_attributes {
    my ($self, $o) = @_;

    $tags->{$o->{tagname}}->{attributes}->{style}->{filter} = \&_filter_style;

    my $output = '';
    while(my ($key, $value) = each(%{ $o->{attr} })) {
        if ($tags->{$tagname}->{attributes}->{$key}->{filter}) {
            $output .= $tags->{$tagname}->{attributes}->{$key}->{filter}->({ tagname => $o->{tagname}, value => $value });
        } else {
            $output .= " $key=\"$value\"" if ($tags->{$o->{tagname}}->{attributes}->{$key});
        }
    }

    return $output;
}

#filter for tags
sub _filter_discard {
    my ($self, $o) = @_;
    return '';
}

sub _filter_tag_style {
    my ($self, $o) = @_;

    $self->{_state}->{text_filter} = \&_filter_tag_style_text;

    return '';
}

sub _filter_tag_style_text {
    my ($self, $o) = @_;

    return '';
}

sub _filter_tag_img {
    my ($self, $o) = @_;

    my $output = "<img";

    if ($o->{attr}->{border} == 0) {
        $o->{attr}->{style} .= " border: 0px;"
    };

    $output .= $self->_handle_attributes({ tagname => 'img', attr => $o->{attr} });

    $output .= " /" if $o->{attr}->{'/'};
    $output .= ">";
    return $output;
}

sub _filter_tag_font {
    my ($self, $o) = @_;

    my $output = "<span";

    if ((lc($o->{attr}->{color}) or '') =~ m/([a-f]+|\#[\da-f]{3,6})/) {
        $o->{attr}->{style} .= "color: $1;";
    }

    $output .= $self->_handle_attributes({ tagname => 'span', attr => $o->{attr} });

    $output .= ">";

    return $output;
}

sub _filter_tag_table {
    my ($self, $o) = @_;

    my $output = "<table";

    if ((lc($o->{attr}->{width}) or '') =~ m/^(\d{1,4})$/) {
        $o->{attr}->{style} .= "width: $1px;";
    }

    $output .= $self->_handle_attributes({ tagname => 'table', attr => $o->{attr} });

    $output .= ">";

    return $output;
}


sub _filter_tag_font_end {
    my ($self, $o) = @_;

    my $output = "</span>";
    return $output;
}

#filter for attributes
my $styles = {
    img => { border => {} },
    span => { color => {} },
    table => { width => {} },
};


#TODO this is probably to crude
sub _filter_style {
    my ($self, $o) = @_;

    my $output = '';

    my @css_attr = split(/;/, $o->{value});

    foreach(@css_attr) {
        my ($key, $value) = split(/:/, $_);
        $output .= "$key: $value;" if $styles->{$o->{tagname}}->{$key};
    }

    return $output;
}

1;
