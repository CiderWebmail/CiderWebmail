package CiderWebmail::Part::TextCalendar;

use Moose;

use Data::ICal;
use DateTime::Format::ISO8601;
use HTML::Entities;

use Text::Autoformat;

use Carp qw/ croak /;

extends 'CiderWebmail::Part';
has renderable          => (is => 'rw', isa => 'Bool', default => 1 );
has render_as_stub      => (is => 'rw', isa => 'Bool', default => 0 );
has message             => (is => 'rw', isa => 'Bool', default => 0 );

=head2 render()

Render a text/calendar body part.

=cut

sub render {
    my ($self) = @_;

    croak('no part set') unless defined $self->body;

    my $cal = Data::ICal->new(data => $self->body);
    my $dt = DateTime::Format::ISO8601->new;

    my @events;
    foreach ( @{$cal->entries} ) {
        my $entry = $_;
        my $start = $entry->property('dtstart') || next;
        my $end = $entry->property('dtend') || next;
        my $summary = $entry->property('summary') || next;

        my $description;
        if ($entry->property('description')) {
            $description = $entry->property('description');
            $description = (autoformat($description->[0]->value, { tabspace => 4, all => 1 }) or '');
            $description = HTML::Entities::encode($description);
            $description =~ s/\n/<br \/>/gxm;
        }
       
        my $dt_start = $dt->parse_datetime($start->[0]->value);
        my $dt_end = $dt->parse_datetime($end->[0]->value);

        push(@events, {
            start => HTML::Entities::encode(join("", $dt_start->ymd("-"), ", ", $dt_start->time(":")), '<>&'),
            end => HTML::Entities::encode(join("", $dt_end->ymd("-"), ", ", $dt_end->time(":")), '<>&'),
            summary => HTML::Entities::encode($summary->[0]->value, '<>&'),
            description => $description,
        });
    }

    return $self->c->view->render_template({ c => $self->c, template => 'TextCalendar.xml', stash => { events => \@events } });
}

=head2 supported_type()

returns the cntent type this plugin can handle

=cut

sub supported_type {
    return 'text/calendar';
}

1;
