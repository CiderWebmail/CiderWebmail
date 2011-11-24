package CiderWebmail::Message::Forwarded;

use Moose;
use MIME::Parser;
use CiderWebmail::Header;

has entity          => (is => 'rw', isa => 'Object'); #MIME::Entity
has message_string  => (is => 'rw', isa => 'Str', required => 1);

=head1 NAME

CiderWebmail::Message::Forwarded - represents a message/rfc822 body part

=head1 DESCRIPTION

See L<CiderWebmail::Message>

=head1 METHODS

=head2 get_header($header)

=cut

sub BUILD {
    my ($self) = @_;

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);

    $self->entity($parser->parse_data($self->message_string));
}

sub get_header {
    my ($self, $header) = @_;

    my $data = $self->entity->head->get($header);
    chomp $data if defined $data;
    return CiderWebmail::Header::transform({ type => $header, data => $data });
}

=head1 AUTHOR

Stefan Seifert <nine@cpan.org>
Mathias Reitinger <mathias.reitinger@loop0.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
