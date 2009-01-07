package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

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

    foreach my $folder ( @{$o->{folders}} ) {
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
