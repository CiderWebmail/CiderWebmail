package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

sub add_foldertree_uris {
    my $c = shift;
    my $o = shift;
   
    die unless defined $o->{folders};

    my $separator = $c->model('IMAPClient')->separator($c);

    foreach my $folder ( @{$o->{folders}} ) {
        my $path = (defined($o->{path}) ? join($separator, $o->{path}, $folder->{name}) : $folder->{name});
        foreach (@{ $o->{uris} }) {
            $folder->{"uri_$_->{action}"} = $c->uri_for("/mailbox/$path/$_->{uri}");
        }
        
        if (defined($folder->{folders})) { #if we have any subfolders
            add_foldertree_uris($c, {
                path    => $path,
                folders => $folder->{folders},
                uris    => $o->{uris},
            });
        }
    }
}

1;
