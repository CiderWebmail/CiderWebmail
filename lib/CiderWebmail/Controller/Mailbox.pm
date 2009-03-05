package CiderWebmail::Controller::Mailbox;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Mailbox;
use CiderWebmail::Util;
use DateTime;

=head1 NAME

CiderWebmail::Controller::Mailbox - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 setup

Gets the selected mailbox from the URI path and sets up the stash.

=cut

sub setup : Chained('/') PathPart('mailbox') CaptureArgs(1) {
    my ( $self, $c, $mailbox ) = @_;
    $c->stash->{folder} = $mailbox;
    $c->stash->{folders_hash}{$mailbox}{selected} = 'selected';
    $c->stash->{uri_compose} = $c->uri_for("/mailbox/$mailbox/compose");
}

=head2 view 

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    unless ( $c->stash->{mbox} ) {
        $c->stash->{mbox} = CiderWebmail::Mailbox->new($c, {mailbox => $c->stash->{folder}});
    }

    my $sort = ($c->req->param('sort') or 'date');
    my @messages = map +{
                %{ $_ },
                uri_view => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}"),
                uri_delete => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}/delete"),
            }, @{ $c->stash->{mbox}->list_messages_hash($c, { sort => [ $sort ] }) };
    
    my %groups;
    
    foreach (@messages) {
        my $name;

        if ($sort eq 'date') {
            $name = $_->{head}->{date}->ymd;
        }

        if ($sort =~ m/(from|to)/) {
            if (defined($_->{head}->{$1}->name)) {
                $name = $_->{head}->{$1}->name;
            } elsif (defined($_->{head}->{$1}->address)) {
                $name = $_->{head}->{$1}->address;
            } else {
                $name = 'unknown';
            }
        }

        if ($sort eq 'subject') {
            $name = $_->{head}->{subject};
        }

        push @{ $groups{$name} }, $_;
    }

    my $clean_uri = $c->req->uri;
    $clean_uri =~ s/[?&]sort=\w+//;
    $c->stash({
        groups          => [ map +{
            name => 
                $sort eq 'date'
                    ? "$_, " . DateTime->new(year => substr($_, 0, 4), month => substr($_, 5, 2), day => substr($_, 8))->day_name #sorting by date
                    : $_, #default sort by $foo
            messages => $groups{$_}
        }, sort keys %groups ],
        messages        => \@messages,
        uri_quicksearch => $c->uri_for($c->stash->{folder} . '/quicksearch'),
        (map {("uri_sorted_$_" => "$clean_uri?sort=$_")} qw(from subject date)),
        template        => 'mailbox.xml',
    });
}

sub search : Chained('setup') PathPart('quicksearch') {
    my ( $self, $c, $searchfor ) = @_;
    $searchfor ||= $c->req->param('text');

    my $mbox = CiderWebmail::Mailbox->new($c, { mailbox => $c->stash->{folder} });
    $mbox->simple_search($c, { searchfor => $searchfor });
    
    $c->stash({
        mbox => $mbox,
    });

    $c->forward('view');
}



=head1 AUTHOR

Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
