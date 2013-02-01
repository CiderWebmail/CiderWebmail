package CiderWebmail::Header;
use warnings;
use strict;

use Mail::Address;
use Time::Piece;
use Date::Parse;

use Carp qw/ croak carp cluck /;

use CiderWebmail::Util qw/ decode_mime_words /;


=head2 transform({ type => $header_name, data => $header_data })

'transform' a header from the 'raw' state (the way it was returned from the server) to an appropriate object.
if no appropriate object exists the header will be decoded (using decode_mime_words()) and UTF-8 encoded

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
        from        => \&_transform_address,
        to          => \&_transform_address,
        cc          => \&_transform_address,
        'reply-to'  => \&_transform_address,
        'list-post' => \&_transform_address,
        date        => \&_transform_date,
    };

    return $headers->{$o->{type}}->($o) if exists $headers->{$o->{type}};

    #if we have no appropriate transfrom function decode the header and return it
    return decode_mime_words({ data => ($o->{data} or '')});
}

sub _transform_address {
    my ($o) = @_;

    #here data might be defined but empty (no address given for example no Cc address)
    #we still need a empty Mail::Address object so we don't break templates that rely on it
    return [Mail::Address->parse('')] unless length($o->{data} // '');

    $o->{data} = decode_mime_words($o);

    #TODO this breaks when we have more than one address
    #$o->{data} =~ s/^<(.*)>$/$1/;
    #$o->{data} =~ s/mailto://gi;

    my @address = Mail::Address->parse($o->{data});

    return \@address;
}

sub _transform_date {
    my ($o) = @_;

    croak("data not set") unless defined $o->{data};

    my $date = Time::Piece->new(Date::Parse::str2time $o->{data});

    return $date;
}

1;
