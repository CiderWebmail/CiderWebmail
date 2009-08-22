package CiderWebmail::Controller::Mailbox;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Mailbox;
use CiderWebmail::Util;
use DateTime;
use URI::QueryParam;

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

my $local_timezone = (eval { DateTime::TimeZone->new(name => "local"); } or 'UTC');

=head2 view

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    my $mailbox = $c->stash->{mbox} ||= CiderWebmail::Mailbox->new(c => $c, mailbox => $c->stash->{folder});
    my $settings = $c->model('DB::Settings')->find_or_new({user => $c->user->id});

    my $sort = ($c->req->param('sort') or $settings->sort_order or 'date');
    $settings->set_column(sort_order => $sort);
    $settings->update_or_insert();

    my $filter = $c->req->param('filter');

    my @uids = $mailbox->uids({ sort => [ $sort ], filter => $filter });

    my $reverse = $sort =~ s/\Areverse\W+//;

    my (@messages, @groups);
    my ($start, $length);

    ($start)  = ($c->req->param('start') or '')  =~ /(\d+)/;
    $start ||= 0;
    ($length) = ($c->req->param('length') or '') =~ /(\d+)/;
    $length ||= 250;
    @uids = $start <= @uids ? splice @uids, $start, $length : ();

    if (@uids) {
        my %messages = map { ($_->{uid} => {
                    %{ $_ },
                    uri_view => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}"),
                    uri_delete => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}/delete"),
                }) } @{ $mailbox->list_messages_hash({ uids => \@uids }) };
        @messages = map $messages{$_}, @uids;

        foreach (@messages) {
            $_->{head}->{date}->set_time_zone($c->config->{time_zone} or $local_timezone);

            my $name;

            if ($sort eq 'date') {
                $name = $_->{head}->{date}->ymd;
            }

            if ($sort =~ m/(from|to)/) {
                my $address = $_->{head}->{$1}->[0];
                $name = $address ? ($address->name ? $address->address . ': ' . $address->name : $address->address) : 'Unknown';
            }

            if ($sort eq 'subject') {
                $name = $_->{head}->{subject};
                $name =~ s/\A\s+//;
                $name =~ s/\A(re:|fwd?:)\s*//i;
                $name =~ s/\s+\z//;
            }
            
            if (not @groups or $groups[-1]{name} ne ($name or '')) {
                push @groups, {name => $name, messages => []};
            }

            push @{ $groups[-1]{messages} }, $_;
        }

        DateTime->DefaultLocale($c->config->{language}); # is this really a good place for this?

        if ($sort eq 'date') {
            $_->{name} .= ', ' . DateTime->new(year => substr($_->{name}, 0, 4), month => substr($_->{name}, 5, 2), day => substr($_->{name}, 8))->day_name foreach @groups;
        }
    }

    my $sort_uri = $c->req->uri->clone;
    $c->stash({
        messages        => \@messages,
        uri_quicksearch => $c->uri_for($c->stash->{folder}),
        template        => 'mailbox.xml',
        groups          => \@groups,
        filter          => $filter,
        sort            => scalar $c->req->param('sort'),
        "sort_$sort"    => 1,
        (map {
            $sort_uri->query_param(sort => ($_ eq $sort and not $reverse) ? "reverse $_" : $_);
            ("uri_sorted_$_" => $sort_uri->as_string)
        } qw(from subject date)),
    });
}

=head2 create_subfolder

Create a subfolder of this mailbox

=cut

sub create_subfolder : Chained('setup') PathPart {
    my ( $self, $c ) = @_;

    if (my $name = $c->req->param('name')) {
        $c->model('IMAPClient')->create_mailbox($c, {mailbox => $c->stash->{folder}, name => $name});
        $c->res->redirect($c->uri_for('/mailboxes'));
    }

    $c->stash({
        template => 'create_mailbox.xml',
    });
}

=head2 delete

Delete a folder

=cut

sub delete : Chained('setup') PathPart {
    my ( $self, $c ) = @_;
    
    $c->model('IMAPClient')->delete_mailbox($c, {mailbox => $c->stash->{folder}});

    $c->res->redirect($c->uri_for('/mailboxes'));
}

=head1 AUTHOR

Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
