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

    $mailbox =~ s';(?!;)'/'gmx; # unmask / in mailbox name
    $mailbox =~ s!;;!;!gmx;

    $c->stash->{folder} = $mailbox;
    $c->stash->{folders_hash}{$mailbox}{selected} = 'selected';
    $c->stash->{uri_compose} = $c->uri_for("/mailbox/$mailbox/compose");

    return;
}

=head2 view

=cut

sub view : Chained('setup') PathPart('') Args(0) {
    my ( $self, $c ) = @_;

    my $mailbox = $c->stash->{mbox} ||= CiderWebmail::Mailbox->new(c => $c, mailbox => $c->stash->{folder});
    my $settings = $c->model('DB::Settings')->find_or_new({user => $c->user->id});

    my $full_sort = ($c->req->param('sort') or $settings->sort_order or 'reverse date');
    my $sort = $full_sort;
    $settings->set_column(sort_order => $full_sort);
    $settings->update_or_insert();

    my $filter = $c->req->param('filter');

    my $range;
    if ($c->req->param('after_uid')) {
        croak unless $c->req->param('after_uid') =~ m/\A\d+\Z/mx;
        $range = $c->req->param('after_uid').":*";
    }

    my @uids = $mailbox->uids({ sort => [ $full_sort ], filter => $filter, range => $range });

    my $reverse = $sort =~ s/\Areverse\W+//xm;

    my (@messages, @groups);
    my ($start, $length);

    ($start)  = ($c->req->param('start') or '')  =~ /(\d+)/xm;
    $start ||= 0;
    ($length) = ($c->req->param('length') or '') =~ /(\d+)/xm;
    $length ||= 100;
    @uids = $start <= @uids ? splice @uids, $start, $length : ();

    unless ($start) { # $start is only > 0 for AJAX requests loading more messages. No need for a foldertree in that case.
        CiderWebmail::Util::add_foldertree_to_stash($c);

        $c->stash->{folder_data} = $c->stash->{folders_hash}{$c->stash->{folder}};
    }
    
    if (@uids) {
        my %messages = map { ($_->{uid} => {
                    %{ $_ },
                    uri_view => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}"),
                    uri_delete => $c->uri_for("/mailbox/$_->{mailbox}/$_->{uid}/delete"),
                }) } @{ $mailbox->list_messages_hash({ uids => \@uids }) };
        @messages = map { $messages{$_} } @uids;

        # yes, this is ugly as hell
        $Petal::I18N::Domain = 'CiderWebmail';
        my $translation_service = Petal::TranslationService::Gettext->new(
            domain => 'CiderWebmail',
            locale_dir => $c->config->{root} . '/locale',
            target_lang => $c->config->{language} || 'en',
        );

        foreach (@messages) {
            #a range of 123:* *always* returns the laster message, if no messages are after UID123 the message with UID123 is returned, ignore it here
            next if ($c->req->param('after_uid') and ($_->{uid} == $c->req->param('after_uid')));

            $_->{head}->{subject} = $translation_service->maketext('No Subject') unless defined $_->{head}->{subject} and length $_->{head}->{subject}; # '0' is an allowed subject...

            my $name;

            if ($sort eq 'date') {
                $name = $_->{head}->{date}->ymd;
            }

            if ($sort =~ m/(from|to)/xm) {
                my $address = $_->{head}->{$1}->[0];
                $name = $address ? ($address->name ? $address->address . ': ' . $address->name : $address->address) : 'Unknown';
            }

            if ($sort eq 'subject') {
                $name = $_->{head}->{subject};
                $name =~ s/\A \s+//xm;
                $name =~ s/\A (re: | fwd?:) \s*//ixm;
                $name =~ s/\s+ \z//xm;
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

    $c->stash->{no_translation} = 1 if $start; # $start is only > 0 for AJAX requests loading more messages. No need for translataion in that case.

    my $sort_uri = $c->req->uri->clone;
    $c->stash({
        messages        => \@messages,
        uri_quicksearch => $c->uri_for($c->stash->{folder}),
        template        => 'mailbox.xml',
        groups          => \@groups,
        filter          => $filter,
        sort            => $full_sort,
        "sort_$sort"    => 'sorted',
        reverse         => $reverse ? 'reverse' : undef,
        (map {
            $sort_uri->query_param(sort => ($_ eq $sort and not $reverse) ? "reverse $_" : $_);
            ("uri_sorted_$_" => $sort_uri->as_string)
        } qw(from subject date)),
    });

    return;
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

    return;
}

=head2 delete

Delete a folder

=cut

sub delete : Chained('setup') PathPart {
    my ( $self, $c ) = @_;
    
    $c->model('IMAPClient')->delete_mailbox($c, {mailbox => $c->stash->{folder}});

    return $c->res->redirect($c->uri_for('/mailboxes'));
}

=head1 AUTHOR

Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
