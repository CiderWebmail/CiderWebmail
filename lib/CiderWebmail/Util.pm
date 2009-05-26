package CiderWebmail::Util;

use warnings;
use strict;

use DateTime;
use DateTime::Format::Mail;

sub add_foldertree_uri_view {
    my $c = shift;
    my $o = shift;
   
    die unless defined $o->{folders};

    foreach my $folder ( @{$o->{folders}} ) {
        $folder->{uri_view} = $c->uri_for("/mailbox/". (defined($o->{path}) ? join($c->model->separator($c), $o->{path}, $folder->{name}) : $folder->{name}));
        
        if (defined($folder->{folders})) { #if we have any subfolders
            add_foldertree_uri_view($c,
                {
                    path => (defined($o->{path}) ? join($c->model->separator($c), $o->{path}, $folder->{name}) : $folder->{name}),
                    folders => $folder->{folders}
                });
        }
    }
}

1;
