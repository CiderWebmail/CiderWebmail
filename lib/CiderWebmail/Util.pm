package CiderWebmail::Util;

use warnings;
use strict;

use MIME::Words qw/ decode_mimewords /;
use DateTime;
use DateTime::Format::Mail;

sub decode_header {
    my ($o) = @_;

    return '' unless $o->{header};

    my $header;

    foreach ( decode_mimewords( $o->{header} ) ) {
        if ( @$_ > 1 ) {
            unless (eval {
                    my $converter = Text::Iconv->new($_->[1], "utf-8");
                    my $part = $converter->convert( $_->[0] );
                    $header .= $part if defined $part;
                }) {
                warn "unsupported encoding: $_->[1]";
                $header .= $_->[0];
            }
        } else {
            $header .= $_->[0];
        }
    }

    return $header;
}

sub date_to_datetime {
    my ($o) = @_;

    return '' unless $o->{date};

    #some mailers specify (CEST)... Format::Mail isn't happy about this
    #TODO better solution
    $o->{date} =~ s/\([a-zA-Z]+\)$//;

    my $dt = DateTime::Format::Mail->new();
    $dt->loose;

    my $date = eval { $dt->parse_datetime($o->{date}) };
    unless ($date) {
        warn "$@ parsing $o->{date}";
        $date = DateTime->from_epoch(epoch => 0); # just return a DateTime object so we can continue
    }

    return $date;
}

sub add_foldertree_uri_view {
    my $c = shift;
    my $o = shift;
   
    die unless defined $o->{folders};

    foreach ( @{$o->{folders}} ) {
        my $folder = $_;
        $folder->{uri_view} = $c->uri_for("/mailbox/". (defined($o->{path}) ? join($c->model->separator($c), $o->{path}, $folder->{name}) : $folder->{name}));
        
        if (defined($folder->{folders})) { #if we have any subfolders
            add_foldertree_uri_view($c,
                {
                    path => (defined($o->{path}) ? join($c->{model}->separator($c), $o->{path}, $folder->{name}) : $folder->{name}),
                    folders => $folder->{folders}
                });
        }
    }
}

1;
