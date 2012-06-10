package CiderWebmail::Header;
use warnings;
use strict;

use Mail::Address;
use Time::Piece;
use Text::Iconv;
use Date::Parse;
use MIME::Words qw/ decode_mimewords /;

use Carp qw/ croak carp /;


=head2 transform({ type => $header_name, data => $header_data })

'transform' a header from the 'raw' state (the way it was returned from the server) to an appropriate object.
if no appropriate object exists the header will be decoded (using decode_mimewords()) and UTF-8 encoded

the following 'transformations' take place:

=over 4

=item * from -> Mail::Address object

=item * to -> Mail::Address object

=item * cc -> Mail::Address object

=item * date -> CiderWebmail::Date object

=back

=cut

sub transform {
    my ($o) = @_;

    croak unless defined $o->{type};
    return unless defined $o->{data};

    $o->{type} = lc($o->{type});

    my $headers = {
        from       => \&_transform_address,
        to         => \&_transform_address,
        cc         => \&_transform_address,
        'reply-to' => \&_transform_address,
        date       => \&_transform_date,
    };

    return $headers->{$o->{type}}->($o) if exists $headers->{$o->{type}};

    #if we have no appropriate transfrom function decode the header and return it
    return _decode_header({ data => ($o->{data} or '')});
}

sub _transform_address {
    my ($o) = @_;

    return unless defined $o->{data};

    my @address = Mail::Address->parse(_decode_header($o));

    return \@address;
}

sub _transform_date {
    my ($o) = @_;

    croak("data not set") unless defined $o->{data};

    my $date = Time::Piece->new(Date::Parse::str2time $o->{data});

    return $date;
}

sub _decode_header {
    my ($o) = @_;

    return '' unless defined $o->{data};

    my $header;

    foreach ( decode_mimewords( $o->{data} ) ) {
        if ( @$_ > 1 ) {
            unless (eval {
                    my $converter = Text::Iconv->new($_->[1], "utf-8");
                    my $part = $converter->convert( $_->[0] );
                    utf8::decode($part);
                    $header .= $part if defined $part;
                }) {
                carp("unable to convert $_->[1] to utf-8 using Text::Iconv: $!");
                utf8::decode($_->[0]);
                $header .= $_->[0];
            }
        } else {
            utf8::decode($_->[0]);
            $header .= $_->[0];
        }
    }

    return $header;
}

1;
