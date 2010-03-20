use strict;
use warnings;

use Test::More tests => 6;
use CiderWebmail::Message::Forwarded;

ok(my $message = CiderWebmail::Message::Forwarded->new(entity => CiderWebmail::Mock::Entity->new));
is($message->as_string, 'string');
is($message->header_formatted, 'string');
is($message->mark_read, undef);
is($message->delete, undef);
is($message->move, undef);

package CiderWebmail::Mock::Entity;

sub new {
    return bless {};
}

sub head {
    my ($self) = @_;
    return $self;
}

sub as_string {
    return 'string';
}
