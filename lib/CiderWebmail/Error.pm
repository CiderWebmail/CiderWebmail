package CiderWebmail::Error;
use Moose;
with 'Throwable';

=head1 NAME

CiderWebmail::Error - Error Handling in CiderWebmail

=cut

=head1 DESCRIPTION

Base class for CiderWebmail exceptions. 

=cut

use overload
  q{""}    => 'as_string',
  fallback => 1;

#http status code that gets return to the http client if this is the last error
has code => (
     is  => 'ro',
     isa => 'Int',
     required => 1,
);

#error id to identify the error (used in ajax requests to handle different error conditions)
has error => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

#status message reportet to the user
has message => (
     is  => 'ro',
     isa => 'Str',
     required => 1,
);

#detail message reportet to the user
has detail => (
     is  => 'ro',
     isa => 'Str',
     required => 0,
);

#debug message reportet to the user
has debug => (
     is  => 'ro',
     isa => 'Str',
     required => 0,
);

sub as_string {
    my ($self) = @_;

    my $message = join(" ", $self->code, $self->message, '(' . $self->error .')', , ($self->detail ? '(' . $self->detail . ')' : ''));

    #TODO cleanup input values when building
    $message =~ s/\n//g;

    return $message;
}

1;
