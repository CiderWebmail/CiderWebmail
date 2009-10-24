package CiderWebmail::Message::Forwarded;

use Moose;

extends 'CiderWebmail::Message';

=head1 NAME

CiderWebmail::Message::Forwarded - represents a message/rfc822 body part

=head1 DESCRIPTION

See L<CiderWebmail::Message>

=head1 METHODS

=head2 get_header($header)

=cut

sub get_header {
    my ($self, $header) = @_;

    my $data = $self->entity->head->get($header);
    chomp $data if defined $data;
    return $self->c->model('IMAPClient')->transform_header($self->c, { header => $header, data => $data });
}

=head2 header_formatted()

=cut

sub header_formatted {
    my ($self) = @_;

    return $self->entity->head->as_string;
}

=head2 mark_read()

=cut

sub mark_read {
    # no use in marking an embedded message
    return;
}

=head2 delete()

=cut

sub delete {
    # no use in deleting an embedded message
    return;
}

=head2 move()

=cut

sub move {
    # no use in deleting an embedded message
    return;
}

=head2 as_string()

=cut

sub as_string {
    my ($self) = @_;

    return $self->entity->as_string;
}

=head1 AUTHOR

Stefan Seifert <nine@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
