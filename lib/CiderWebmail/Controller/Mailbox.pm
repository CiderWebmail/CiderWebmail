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

    my $mailbox = $c->stash->{mbox} ||= CiderWebmail::Mailbox->new($c, {mailbox => $c->stash->{folder}});

    my $sort = ($c->req->param('sort') or 'date');

    my @uids = $mailbox->uids({ sort => [ $sort ] });

    if (defined $c->req->param('start')) {
        my ($start) = $c->req->param('start')  =~ /(\d+)/;
        my ($end) =   $c->req->param('length') =~ /(\d+)/;
        @uids = splice @uids, ($start or 0), ($end or 0);
    }

    my @messages = map +{
                %{ $_ },
                uri_view => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}"),
                uri_delete => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}/delete"),
            }, @{ $mailbox->list_messages_hash($c, { uid => \@uids }) };

    my %groups;

    foreach (@messages) {
        my $name;

        if ($sort eq 'date') {
            $name = ($_->{head}->{date} or DateTime->from_epoch(epoch => 0))->ymd;
        }

        if ($sort =~ m/(from|to)/) {
            my $address = $_->{head}->{$1}->[0];
            $name = ($address->name ? $address->name : $address->address);
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
    $mbox->simple_search({ searchfor => $searchfor });
    
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
