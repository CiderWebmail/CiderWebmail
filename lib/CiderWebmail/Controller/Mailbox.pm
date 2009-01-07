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
        my $mbox = CiderWebmail::Mailbox->new($c, {mailbox => $c->stash->{folder}});
        $c->stash->{mbox} = $mbox->list_messages_hash($c);
    }

    my $sort = ($c->req->param('sort') or 'date');
    my @messages = sort { $a->{$sort} cmp $b->{$sort} }
        map +{
                %{ $_ },
                uri_view => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}"),
                uri_delete => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}/delete"),
            }, @{ $c->stash->{mbox} };
    
    my %groups;
    
    foreach (@messages) {
        my $name = $sort eq 'date' ? $_->{$sort}->ymd : $_->{$sort};
        push @{ $groups{$name} }, $_;
    }

    my $clean_uri = $c->req->uri;
    $clean_uri =~ s/[?&]sort=\w+//;
    $c->stash({
        groups          => [ map +{
            name => $sort eq 'date' ? "$_, " . DateTime->new(year => substr($_, 0, 4), month => substr($_, 5, 2), day => substr($_, 8))->day_name : $_,
            messages => [sort {$a->{$sort} cmp $b->{$sort}} @{ $groups{$_} }]
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

    my $mbox = CiderWebmail::Mailbox->new($c, {mailbox => $c->stash->{folder}});

    $c->stash({
        mbox => $mbox->simple_search($c, { searchfor => $searchfor }),
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
