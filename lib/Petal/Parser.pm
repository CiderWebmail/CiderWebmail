# ------------------------------------------------------------------
# Petal::Parser - Fires Petal::Canonicalizer events
# ------------------------------------------------------------------
# A Wrapper class for MKDoc::XML:TreeBuilder which is meant to be
# used for Petal::Canonicalizer.
# ------------------------------------------------------------------
package Petal::Parser;
use MKDoc::XML::TreeBuilder;
use MKDoc::XML::Decode;
use strict;
use warnings;
use Carp;

use Petal::Canonicalizer::XML;
use Petal::Canonicalizer::XHTML;

use vars qw /@NodeStack @MarkedData $Canonicalizer
	     @NameSpaces @XI_NameSpaces @MT_NameSpaces @MT_Name_Cur $Decode/;


# this avoid silly warnings
sub sillyness
{
    $Petal::NS,
    $Petal::NS_URI,
    $Petal::XI_NS_URI;
}


sub new
{
    my $class = shift;
    $class = ref $class || $class;
    return bless { @_ }, $class;
}


sub process
{
    my $self = shift;
    local $Canonicalizer = shift;
    my $data_ref = shift;
    
    local @MarkedData    = ();
    local @NodeStack     = ();
    local @NameSpaces    = ();
    local @MT_NameSpaces = ();
    local @MT_Name_Cur   = ('main');
    local $Decode        = new MKDoc::XML::Decode (qw /xml numeric/);
    
    $data_ref = (ref $data_ref) ? $data_ref : \$data_ref;
    
    my @top_nodes = MKDoc::XML::TreeBuilder->process_data ($$data_ref);
    for (@top_nodes) { $self->generate_events ($_) }
    
    @MarkedData = ();
    @NodeStack  = ();
}


# generate_events();
# ------------------
# Once the HTML::TreeBuilder object is built and elementified, it is
# passed to that subroutine which will traverse it and will trigger
# proper subroutines which will generate the XML events which are used
# by the Petal::Canonicalizer module
sub generate_events
{
    my $self = shift;
    my $tree = shift;
    
    if (ref $tree)
    {
	my $tag  = $tree->{_tag};
	my $attr = { map { /^_/ ? () : ( $_ => $Decode->process ($tree->{$_}) ) } keys %{$tree} };
	
	if ($tag eq '~comment')
	{
	    generate_events_comment ($tree->{text});
	}
	else
	{
	    # decode attributes
	    for (keys %{$tree})
	    {
		$tree->{$_} = $Decode->process ( $tree->{$_} )
		   unless (/^_/);
	    }
	    
	    push @NodeStack, $tree;
	    generate_events_start ($tag, $attr);
	    
	    foreach my $content (@{$tree->{_content}})
	    {
		$self->generate_events ($content);
	    }
	    
	    generate_events_end ($tag);
	    pop (@NodeStack);
	}
    }
    else
    {
	$tree = $Decode->process ( $tree );
	generate_events_text ($tree);
    }
}


sub generate_events_start
{
    local $_ = shift;
    $_ = "<$_>";
    local %_ = %{shift()};
    delete $_{'/'};
    
    # process the Petal namespace
    my $ns = (scalar @NameSpaces) ? $NameSpaces[$#NameSpaces] : $Petal::NS;
    foreach my $key (keys %_)
    {
	my $value = $_{$key};
	if ($value eq $Petal::NS_URI)
	{
	    next unless ($key =~ /^xmlns\:/);
	    delete $_{$key};
	    $ns = $key;
	    $ns =~ s/^xmlns\://;
	}
    }
    
    push @NameSpaces, $ns;
    local ($Petal::NS) = $ns;
    
    # process the XInclude namespace
    my $xi_ns = (scalar @XI_NameSpaces) ? $XI_NameSpaces[$#XI_NameSpaces] : $Petal::XI_NS;
    foreach my $key (keys %_)
    {
	my $value = $_{$key};
	if ($value eq $Petal::XI_NS_URI)
	{
	    next unless ($key =~ /^xmlns\:/);
	    delete $_{$key};
	    $xi_ns = $key;
	    $xi_ns =~ s/^xmlns\://;
	}
    }
    
    push @XI_NameSpaces, $xi_ns;
    local ($Petal::XI_NS) = $xi_ns;
    
    # process the Metal namespace
    my $mt_ns = (scalar @MT_NameSpaces) ? $MT_NameSpaces[$#MT_NameSpaces] : $Petal::MT_NS;
    foreach my $key (keys %_)
    {
	my $value = $_{$key};
	if ($value eq $Petal::MT_NS_URI)
	{
	    next unless ($key =~ /^xmlns\:/);
	    delete $_{$key};
	    $mt_ns = $key;
	    $mt_ns =~ s/^xmlns\://;
	}
    }
    
    push @MT_NameSpaces, $mt_ns;
    local ($Petal::MT_NS) = $mt_ns;

    # process the Metal current name
    my $pushed = 0;

    $_{"$mt_ns:define-macro"} and do {
        $pushed = 1;
        delete $_{"$mt_ns:define-slot"};
        push @MT_Name_Cur, delete $_{"$mt_ns:define-macro"};
    };
     
    $_{"$mt_ns:fill-slot"} and do {
        $pushed = 1;
        push @MT_Name_Cur, "__metal_slot__" . delete $_{"$mt_ns:fill-slot"};
    };    

    push @MT_Name_Cur, $MT_Name_Cur[$#MT_Name_Cur] unless ($pushed);

    my $dont_skip = grep /^\Q$Petal::MT_NAME_CUR\E$/, @MT_Name_Cur;
    $Canonicalizer->StartTag() if ($dont_skip);
}


sub generate_events_end
{
    local $_ = shift;
    local $_ = "</$_>";
    local ($Petal::NS)    = pop (@NameSpaces);
    local ($Petal::XI_NS) = pop (@XI_NameSpaces);
    local ($Petal::MT_NS) = pop (@MT_NameSpaces);
    
    my $skip = 1;
    for (@MT_Name_Cur) { $_ eq $Petal::MT_NAME_CUR and $skip = 0 }

    my $dont_skip = grep /^\Q$Petal::MT_NAME_CUR\E$/, @MT_Name_Cur;
    $Canonicalizer->EndTag() if ($dont_skip);
    pop (@MT_Name_Cur);
}


sub generate_events_text
{

    my $skip = 1;
    for (@MT_Name_Cur) { $_ eq $Petal::MT_NAME_CUR and $skip = 0 }
    
    my $data = shift;
    $data =~ s/\&/&amp;/g;
    $data =~ s/\</&lt;/g;
    local $_ = $data;
    local ($Petal::NS)    = $NameSpaces[$#NameSpaces];
    local ($Petal::XI_NS) = $XI_NameSpaces[$#XI_NameSpaces];
    local ($Petal::MT_NS) = $MT_NameSpaces[$#MT_NameSpaces];

    my $dont_skip = grep /^\Q$Petal::MT_NAME_CUR\E$/, @MT_Name_Cur;
    $Canonicalizer->Text() if ($dont_skip);
}


sub generate_events_comment
{
    my $skip = 1;
    for (@MT_Name_Cur) { $_ eq $Petal::MT_NAME_CUR and $skip = 0 }
    
    my $data = shift;
    local $_ = '<!--' . $data . '-->';
    
    my $dont_skip = grep /^\Q$Petal::MT_NAME_CUR\E$/, @MT_Name_Cur;
    $Canonicalizer->Text() if ($dont_skip);
}


1;


__END__
