package CiderWebmail::Part::TextCalendar;

use Moose;

use Data::ICal;
use DateTime::Format::ISO8601;

extends 'CiderWebmail::Part';

=head2 render()

Render a text/calendar body part.

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

=head2 content_type()

returns the cntent type this plugin can handle

=cut

sub content_type {
    return 'text/calendar';
}

=head2 renderable()

returns true if this part is renderable

=cut

sub renderable {
    return 1;
}

1;
