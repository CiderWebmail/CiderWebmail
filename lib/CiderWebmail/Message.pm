package CiderWebmail::Message;

use warnings;
use strict;

use Mail::IMAPClient::BodyStructure;

use DateTime;
use Mail::Address;
use DateTime::Format::Mail;
use HTML::Scrubber;

use Text::Iconv;

sub new {
    my ($class, $c, $o) = @_;

    die unless $o->{mailbox};
    die unless $o->{uid};

    #TODO add headers passed here to the header cache
    my $message = {
        c => $c,
        mailbox => $o->{mailbox},
        uid     => $o->{uid}
    };

    bless $message, $class;
}

sub uid {
    my ($self) = @_;

    return $self->{uid};
}

sub mailbox {
    my ($self) = @_;

    return $self->{mailbox};
}

sub get_header {
    my ($self, $header) = @_;

    return scalar $self->{c}->model->get_headers($self->{c}, { uid => $self->uid, mailbox => $self->mailbox, headers => [$header]});
}

#TODO formatting
sub header_formatted {
    my ($self) = @_;

    return $self->{c}->model->get_headers_string($self->{c}, { uid => $self->{uid}, mailbox => $self->{mailbox} });
}

sub subject {
    my ($self) = @_;

    return ($self->get_header('subject') or 'No Subject');
}

sub from {
    my ($self) = @_;

    return $self->get_header('from');
}

sub to {
    my ($self) = @_;

    return $self->get_header('to');
}

sub reply_to {
    my ($self) = @_;

    return $self->get_header('reply-to');
}


sub cc {
    my ($self) = @_;

    return $self->get_header('cc');
}


sub get_headers {
    my ($self) = @_;
    
    return {
        subject     => $self->subject(),
        from        => $self->from,
        date        => $self->date->strftime("%F %T"),
        uid         => $self->uid,
    };
}


#returns a datetime object
sub date {
    my ($self) = @_;

    return $self->get_header('date');
}

sub load_body {
    my ($self) = @_;

    return if defined $self->{renderable};

    my $body_parts = $self->body_parts($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
   
    $self->{renderable} = $body_parts->{renderable};
    $self->{attachments} = $body_parts->{attachments};
}

sub renderable {
    my ($self) = @_;

    $self->load_body unless exists $self->{renderable};

    return (wantarray ? [ values(%{ $self->{renderable} }) ] : $self->{renderable} );
}

sub attachments {
    my ($self) = @_;

    $self->load_body unless exists $self->{attachments};

    return (wantarray ? [ values(%{ $self->{attachments} }) ] : $self->{attachments} );
}

sub delete {
    my ($self) = @_;

    $self->{c}->model->delete_messages($self->{c}, { uids => [ $self->uid ], mailbox => $self->mailbox } );
}

sub as_string {
    my ($self) = @_;

    $self->{c}->model->message_as_string($self->{c}, { uid => $self->uid, mailbox => $self->mailbox } );
}

sub main_body_part {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $self->{mailbox};
    die 'uid not set' unless defined $self->{uid};

    my $renderable = $self->renderable;
  
    #just return the first text/plain part
    #here we should determine the main 'body part' (text/plain > text/html > ???)
    #to use when forwarding/replying to messages and return it
    foreach(values(%{ $renderable })) {
        my $part = $_;
        if (($part->{is_text} or 0) == 1) {
            return $part->{data};
        }
    }
}


sub body_parts {
    my ($self, $c, $o) = @_;

    die 'mailbox not set' unless defined $self->{mailbox};
    die 'uid not set' unless defined $self->{uid};

    my $message = $self->{c}->model->message_as_string($c, { mailbox => $self->{mailbox}, uid => $self->{uid} });

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);

    my $entity = $parser->parse_data($message);

    my @parts = $entity->parts_DFS;
    @parts = ($entity) unless @parts;

   my $part_types = {
        'text/plain' => \&_render_text_plain,
        'text/html' => \&_render_text_html,
    };
 
    my $body_parts = {}; #body parts we render (text/plain, text/html, etc)
    my $attachments = {}; #body parts we don't render (everything else)
    
    my $id = 0;
    foreach (@parts) {
        my $part = $_;

        if (exists $part_types->{$part->effective_type}) {
            my $rendered_part = $part_types->{$part->effective_type}->($c, { part => $part });
            $rendered_part->{id} = $id;
            $body_parts->{$id} = $rendered_part;
        } else {
            $attachments->{$id} = {
                type => $part->effective_type,
                name => ($part->head->mime_attr("content-type.name") or "attachment (".$part->effective_type.")"),
                data => $part->bodyhandle->as_string,
                id   => $id,
            } if $part->bodyhandle;
        }

        $id++;
   }

   return { renderable => $body_parts, attachments => $attachments };
}

sub _render_text_plain {
    my ($c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $charset = $o->{part}->head->mime_attr("content-type.charset");

    my $part = {};
    my $part_string;
    unless ($charset
        and eval {
            my $converter = Text::Iconv->new($charset, "utf-8");
            $part_string = $converter->convert($o->{part}->bodyhandle->as_string);
        }) {

        warn "unsupported encoding: $charset" if $charset;
        $part_string = $o->{part}->bodyhandle->as_string;
    }

    utf8::decode($part_string);
    $part->{data} = Text::Flowed::reformat($part_string);

    $part->{is_text} = 1;

    return $part;
}

sub _render_text_html {
    my ($c, $o) = @_;

    die 'no part set' unless defined $o->{part};

    my $part = {};
    
    my $charset = $o->{part}->head->mime_attr("content-type.charset");
    my $scrubber = HTML::Scrubber->new( allow => [ qw/p b strong i u hr br div span table thead tbody tr th td/ ] );
 
    my @default = (
        0   =>    # default rule, deny all tags
        {
            '*'           => 0, # default rule, deny all attributes
            'href'        => qr{^(?!(?:java)?script)}i,
            'src'         => qr{^(?!(?:java)?script)}i,
            'class'       => 1,
            'style'       => 1,
        }
    );

    my $part_string = $o->{part}->bodyhandle->as_string;
    eval {
        my $converter = Text::Iconv->new($charset, "utf-8");
        $part_string = $converter->convert($part_string);
    } or warn "unsupported encoding: $charset" if $charset;
    utf8::decode($part_string);

    $scrubber->default( @default );
    $part->{data} = $scrubber->scrub($part_string);
    $part->{data} =~ s!<(br|hr)>!<$1/>!g;

    $part->{is_html} = 1;

    return $part;
}


1;
