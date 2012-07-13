package CiderWebmail::Controller::Mailbox;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use CiderWebmail::Mailbox;
use CiderWebmail::Util;
use DateTime;
use URI::QueryParam;

use Carp qw/ croak /;

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

    $c->stash->{uri_folder} = $c->uri_for("/mailbox/$mailbox");
    $c->stash->{uri_compose} = $c->stash->{uri_folder} . '/compose';

    $mailbox =~ s';(?!;)'/'gmx; # unmask / in mailbox name
    $mailbox =~ s!;;!;!gmx;

    $c->stash->{folder} = $mailbox;

    return;
}

=head2 view

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    my $filter = $c->req->param('filter');

    my $mailbox = $c->stash->{mbox} ||= CiderWebmail::Mailbox->new(c => $c, mailbox => $c->stash->{folder});
    my $settings = $c->model('DB::Settings')->find_or_new({user => $c->user->id});

    my $full_sort = ($c->req->param('sort') or $settings->sort_order or 'reverse date');
    my $sort = $full_sort;
    my $reverse = $sort =~ s/\Areverse\W+//xm;

    $settings->set_column(sort_order => $full_sort);
    $settings->update_or_insert();

    my $range;
    if ($c->req->param('after_uid')) {
        croak unless $c->req->param('after_uid') =~ m/\A\d+\Z/mx;
        $range = $c->req->param('after_uid').":*";
    }

    my @uids = $mailbox->uids({ sort => [ $full_sort ], filter => $filter, range => $range });


    my ($start)  = ($c->req->param('start') or 0)  =~ /(\d+)/xm;
    my ($length) = ($c->req->param('length') or 100) =~ /(\d+)/xm;
    @uids = $start <= @uids ? splice @uids, $start, $length : ();

    my @groups;
    if (@uids) {
        my $uri_folder = $c->stash->{uri_folder};
        my %messages = map { ($_->{uid} => {
                    %{ $_ },
                    uri_view => "$uri_folder/$_->{uid}",
                    uri_delete => "$uri_folder/$_->{uid}/delete",
                }) } @{ $mailbox->list_messages_hash({ uids => \@uids }) };

        foreach ( map { $messages{$_} } @uids ) {
            #a range of 123:* *always* returns the last message, if there are no messages are UID123 the message with UID123 is returned, ignore it here
            next if ($c->req->param('after_uid') and ($_->{uid} == $c->req->param('after_uid')));

            $_->{head}->{subject} = $c->stash->{translation_service}->maketext('No Subject') unless defined $_->{head}->{subject} and length $_->{head}->{subject}; # '0' is an allowed subject...

            my $name = CiderWebmail::Util::message_group_name($_, $sort);
           
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

    if ($start) {
        # $start is only > 0 for AJAX requests loading more messages. No need for translataion in that case.
        $c->stash->{no_translation} = 1;
    } else { 
        # No AJAX request - add foldertree
        CiderWebmail::Util::add_foldertree_to_stash($c);
        $c->stash->{folder_data} = $c->stash->{folders_hash}{$c->stash->{folder}};
    }

    my $sort_uri = $c->req->uri->clone;
    $c->stash({
        uri_quicksearch => $c->stash->{uri_folder},
        template        => 'mailbox.xml',
        groups          => \@groups,
        filter          => $filter,
        show_to         => ($c->stash->{folder} =~ m/(Sent|Gesendet|Postausgang|Ausgangsnachrichten)/ixm ? 1 : 0),
        show_from       => ($c->stash->{folder} !~ m/(Sent|Gesendet|Postausgang|Ausgangsnachrichten)/ixm ? 1 : 0),
        sort            => $full_sort,
        "sort_$sort"    => 'sorted',
        reverse         => $reverse ? 'reverse' : undef,
        (map {
            $sort_uri->query_param(sort => ($_ eq $sort and not $reverse) ? "reverse $_" : $_);
            ("uri_sorted_$_" => $sort_uri->as_string)
        } qw(to from subject date)),
    });

    return;
}

=head2 create_subfolder

Create a subfolder of this mailbox

=cut

sub create_subfolder : Chained('setup') PathPart {
    my ( $self, $c ) = @_;

    if (my $name = $c->req->param('name')) {
        $c->model('IMAPClient')->create_mailbox({mailbox => $c->stash->{folder}, name => $name});
        $c->res->redirect($c->uri_for('/mailboxes'));
    }

    CiderWebmail::Util::add_foldertree_to_stash($c); 

    $c->stash({
        template => 'create_mailbox.xml',
    });

    return;
}

=head2 delete

Delete a folder

=cut

sub delete : Chained('setup') PathPart {
    my ( $self, $c ) = @_;
    
    $c->model('IMAPClient')->delete_mailbox({mailbox => $c->stash->{folder}});

    return $c->res->redirect($c->uri_for('/mailboxes'));
}

=head1 AUTHOR

Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
