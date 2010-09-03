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

    $c->stash->{settings} = $c->model('DB::Settings')->find_or_new({user => $c->user->id});

    $c->stash->{uri_folder} = $c->uri_for("/mailbox/$mailbox");
    $c->stash->{uri_compose} = $c->stash->{uri_folder} . '/compose';
    $c->stash->{uri_quicksearch} = $c->stash->{uri_folder};

    $mailbox =~ s';(?!;)'/'gmx; # unmask / in mailbox name
    $mailbox =~ s!;;!;!gmx;

    $c->stash->{folder} = $mailbox;

    unless($c->stash->{mbox}) {
        $c->stash->{mbox} = CiderWebmail::Mailbox->new(c => $c, mailbox => $c->stash->{folder});
    }

    return;
}

sub view : Chained('setup') PathPart('') Args(0) {
    my ($self, $c) = @_;

    my $settings = $c->stash->{settings};

    #Template
    $c->stash->{template} = 'mailbox.xml';

    #Search
    $c->stash->{filter}   = $c->req->param('filter');

    #Column Setup
    $c->stash({
        show_to         => ($c->stash->{folder} =~ m/(Sent|Gesendet|Postausgang|Ausgangsnachrichten)/i ? 1 : 0),
        show_from       => ($c->stash->{folder} !~ m/(Sent|Gesendet|Postausgang|Ausgangsnachrichten)/i ? 1 : 0),
    });

    #Sorting
    $c->stash->{full_sort} = ($c->req->param('sort') or $settings->sort_order or 'reverse date');
    $c->stash->{sort} = $c->stash->{full_sort};
    $c->stash->{reverse} = $c->stash->{sort} =~ s/\Areverse\W+//xm;

    $settings->set_column(sort_order => $c->stash->{full_sort});
    $settings->update_or_insert();

    my $sort_uri = $c->req->uri->clone;
    $c->stash({
        "sort_".$c->stash->{sort}    => 'sorted',
        reverse         => $c->stash->{reverse} ? 'reverse' : undef,
        (map {
            $sort_uri->query_param(sort => ($_ eq $c->stash->{sort} and not $c->stash->{reverse}) ? "reverse $_" : $_);
            ("uri_sorted_$_" => $sort_uri->as_string)
        } qw(to from subject date)),
    });


    #display mode (list vs. threads view)
    my $display = ($c->req->param('display') or '');

    if ($display eq 'threads') {
        $c->stash->{groups} = $c->forward('thread_list');
    } elsif ($display eq 'message_list') {
        $c->stash->{groups} = $c->forward('message_list');
    } else {
        $c->stash->{groups} = $c->forward('message_list');
    }

    unless($c->req->param('start')) {
        #add foldertree unless it's an ajax request
        CiderWebmail::Util::add_foldertree_to_stash($c);
        $c->stash->{folder_data} = $c->stash->{folders_hash}{$c->stash->{folder}};
    }

}

=head2 view

=cut

sub message_list : Private {
    my ( $self, $c ) = @_;

    my $mailbox = $c->stash->{mbox};
    my $settings = $c->stash->{settings};

    my $full_sort = $c->stash->{full_sort};
    my $sort = $c->stash->{sort};
    my $reverse = $c->stash->{reverse};

    my $range;
    if ($c->req->param('after_uid')) {
        croak unless $c->req->param('after_uid') =~ m/\A\d+\Z/mx;
        $range = $c->req->param('after_uid').":*";
    }

    my @uids = $mailbox->uids({ sort => [ $full_sort ], filter => $c->stash->{filter}, range => $range });

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

    return \@groups;
}

sub thread_list : Chained('setup') PathPart {
    my ( $self, $c ) = @_;

    my $full_sort = $c->stash->{full_sort};

    my $mailbox = $c->stash->{mbox};
    my $messages = $mailbox->threads({ filter => $c->stash->{filter}, sort => $full_sort });

    my @uids = map( $_->{uid}, @$messages );

    my ($start)  = ($c->req->param('start') or 0)  =~ /(\d+)/xm;
    my @groups;
    if ($start) { @uids = (); } #wo don't implement incremental message loading yet...
    if(@uids) {
        #quick and dirty hack to make this work
        my %level = map { $_->{uid} => $_->{level} } @$messages;

        my %headers = map { ($_->{uid} => {
                        %{ $_ },
                        uri_view => $c->stash->{uri_folder}."/$_->{uid}",
                        uri_delete => $c->stash->{uri_folder}."/$_->{uid}/delete",
                    }) } @{ $c->model('IMAPClient')->get_headers_hash($c, { mailbox => $c->stash->{folder}, uids => \@uids, headers => [qw/To From Subject Date/] }) } ;

        foreach ( map { $headers{$_} } @uids ) {
            $_->{head}->{subject} = $c->stash->{translation_service}->maketext('No Subject') unless defined $_->{head}->{subject} and length $_->{head}->{subject}; # '0' is an allowed subject...
            $_->{style} = "padding-left: ".( $level{$_->{uid}} - 1)."em";
            
            my $name = CiderWebmail::Util::message_group_name($_, 'subject');
            if ($level{$_->{uid}} == 1) {
                push @groups, {name => $name, messages => []};
            }

            push @{ $groups[-1]{messages} }, $_;
        }
    } 

    return \@groups;
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
