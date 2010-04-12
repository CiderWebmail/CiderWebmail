package CiderWebmail::Part::TextCalendar;

use Moose;

use Data::ICal;
use DateTime::Format::ISO8601;

extends 'CiderWebmail::Part';

=head2 render()

Internal method rendering a text/plain body part.

=cut

sub render {
    my ($self) = @_;

    die 'no part set' unless defined $self->body;

    my $cal = Data::ICal->new(data => $self->body);
    my $dt = DateTime::Format::ISO8601->new;

    my @events;
    foreach ( @{$cal->entries} ) {
        my $entry = $_;
        my $start = $entry->property('dtstart') || next;
        my $end = $entry->property('dtend') || next;
        my $summary = $entry->property('summary') || next;
       
        my $dt_start = $dt->parse_datetime($start->[0]->value);
        my $dt_end = $dt->parse_datetime($end->[0]->value);

        push(@events, {
            start => join("", $dt_start->ymd("-"), ", ", $dt_start->time(":")),
            end => join("", $dt_end->ymd("-"), ", ", $dt_end->time(":")),
            summary => $summary->[0]->value, }
        );
    }

    return $self->c->view->render_template({ c => $self->c, template => 'TextCalendar.xml', stash => { events => \@events } });
}

sub content_type {
    return 'text/calendar';
}

sub is_html {
    return 1;
}

sub renderable {
    return 1;
}

1;
