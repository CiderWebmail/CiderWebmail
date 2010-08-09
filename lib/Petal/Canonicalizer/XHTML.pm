# ------------------------------------------------------------------
# Petal::Canonicalizer::XHTML - Builds an XHTML canonical Petal file
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# Description: This modules mainly implements the XML::Parser
# 'Stream' interface. It receives XML events and builds Petal
# canonical data, i.e.
#
#   <foo petal:if="bar">Hello</foo>
#
# Might be canonicalized to something like
#
#   <?petal:if name="bar"?>
#     <foo>Hello</foo>
#   <?petal:end?>
#
# On top of that, Petal::Canonicalizer::XHTML will self close certain
# XHTML specific tags, like <br /> or <input ... />
# ------------------------------------------------------------------
package Petal::Canonicalizer::XHTML;
use strict;
use warnings;
use base qw /Petal::Canonicalizer::XML/;


# http://lists.webarch.co.uk/pipermail/petal/2002-August/000074.html
# here's a list[1] of empty elements (which need careful handling):
# 
# ---8<---
# area
# base
# basefont
# br
# col
# frame
# hr
# img
# input
# isindex
# link
# meta
# param
# --->8---
# 
# [1] http://www.w3.org/TR/html401/index/elements.html


# $class->StartTag();
# -------------------
# Called for every start tag with a second parameter of the element type.
# It will check for special PETAL attributes like petal:if, petal:loop, etc...
# and rewrite the start tag into @Petal::Canonicalizer::XML::Result accordingly.
#
# For example
#   <foo petal:if="blah">
#
# Is rewritten
#   <?petal:if name="blah"?><foo>...
sub StartTag
{
    Petal::load_code_generator(); # we will use it later

    my $class = shift;
    push @Petal::Canonicalizer::XML::NodeStack, {};
    return if ($class->_is_inside_content_or_replace());
    
    my $tag = $_;
    ($tag) = $tag =~ /^<\s*((?:\w|\:|\-)*)/;
    my $att = { %_ };

    $class->_use_macro ($tag, $att);
    $class->_on_error ($tag, $att);
    $class->_define ($tag, $att);
    $class->_define_slot ($tag, $att);
    $class->_condition ($tag, $att);
    $class->_repeat ($tag, $att);
    $class->_is_xinclude ($tag) and $class->_xinclude ($tag, $att) and return;
    $class->_replace ($tag, $att);
    
    my $petal = quotemeta ($Petal::NS);
    
    # if a petal:replace attribute was set, then at this point _is_inside_content_or_replace()
    # should return TRUE and this code should not be executed
    unless ($class->_is_inside_content_or_replace())
    {
	# for every attribute which is not a petal: attribute,
	# we need to convert $variable into <?var name="variable"?>
	foreach my $key (keys %{$att})
	{
	    next if ($key =~ /^$petal:/);
	    my $text = $att->{$key};
	    my $token_re = $Petal::Hash::String::TOKEN_RE;
	    my @vars = $text =~ /$token_re/gsm;
	    my %vars = map { $_ => 1 } @vars;
	    @vars = sort { length ($b) <=> length ($a) } keys %vars;
	    foreach my $var (@vars)
	    {
		my $command = $var;
		$command =~ s/^\$//;
		$command =~ s/^\{//;
		$command =~ s/\}$//;
		$command = $class->_encode_backslash_semicolon ($command);
		$command = "<?var name=\"$command\"?>";
		$text =~ s/\Q$var\E/$command/g;
	    }
	    $att->{$key} = $text;
	}
	
	$class->_attributes ($tag, $att);
	
	my @att_str = ();
	foreach my $key (keys %{$att})
	{
	    next if ($key =~ /^$petal:/);
	    my $value = $att->{$key};
	    if ($value =~ /^<\?attr/)
	    {
		push @att_str, $value;
	    }
	    else
	    {
		my $tokens = Petal::CodeGenerator->_tokenize (\$value);
		my @res = map {
		    ($_ =~ /$Petal::CodeGenerator::PI_RE/s) ?
		        $_ :
			do {
			    $_ =~ s/\&/&amp;/g;
			    $_ =~ s/\</&lt;/g;
			    $_ =~ s/\>/&gt;/g;
			    $_ =~ s/\"/&quot;/g;
			    $_;
			};
		} @{$tokens};
		push @att_str, $key . '="' . (join '', @res) . '"';
	    }
	}
	my $att_str = join " ", @att_str;
	
	if ( (uc ($tag) eq 'AREA')     or 
	     (uc ($tag) eq 'BASE')     or 
	     (uc ($tag) eq 'BASEFONT') or 
	     (uc ($tag) eq 'BR')       or 
	     (uc ($tag) eq 'COL')      or 
	     (uc ($tag) eq 'FRAME')    or 
	     (uc ($tag) eq 'HR')       or 
	     (uc ($tag) eq 'IMG')      or 
	     (uc ($tag) eq 'INPUT')    or 
	     (uc ($tag) eq 'ISINDEX')  or 
	     (uc ($tag) eq 'LINK')     or 
	     (uc ($tag) eq 'META')     or 
	     (uc ($tag) eq 'PARAM') )
	{
	    if (defined $att->{"$petal:omit-tag"})
	    {
		my $expression = $att->{"$petal:omit-tag"} || 'string:1';
		$Petal::Canonicalizer::XML::NodeStack[$#Petal::Canonicalizer::XML::NodeStack]->{'omit-tag'} = $expression;
		push @Petal::Canonicalizer::XML::Result, (defined $att_str and $att_str) ?
		    "<?if name=\"false:$expression\"?><$tag $att_str /><?end?>" :
		    "<?if name=\"false:$expression\"?><$tag /><?end?>";
	    }
	    else
	    {
		push @Petal::Canonicalizer::XML::Result, (defined $att_str and $att_str) ? "<$tag $att_str />" : "<$tag />";
	    }
	}
	else
	{
	    if (defined $att->{"$petal:omit-tag"})
	    {
		my $expression = $att->{"$petal:omit-tag"} || 'string:1';
		$Petal::Canonicalizer::XML::NodeStack[$#Petal::Canonicalizer::XML::NodeStack]->{'omit-tag'} = $expression;
		push @Petal::Canonicalizer::XML::Result, (defined $att_str and $att_str) ?
		    "<?if name=\"false:$expression\"?><$tag $att_str><?end?>" :
		    "<?if name=\"false:$expression\"?><$tag><?end?>";
	    }
	    else
	    {
		push @Petal::Canonicalizer::XML::Result, (defined $att_str and $att_str) ? "<$tag $att_str>" : "<$tag>";
	    }
	}
	
	$class->_content ($tag, $att);
    }
}


# $class->EndTag();
# -----------------
# Called for every end tag with a second parameter of the element type.
# It will check in the @Petal::Canonicalizer::XML::NodeStack to see if this end-tag also needs to close
# some 'condition' or 'repeat' statements, i.e.
#
#   </li>
#
# Could be rewritten
#
#   </li><?petal:end?>
#
# If the starting LI used a loop, i.e. <li petal:loop="element list">
sub EndTag
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace ( 'endtag' ));
    my ($tag) = $_ =~ /^<\/\s*((?:\w|\:|\-)*)/;
    my $node = pop (@Petal::Canonicalizer::XML::NodeStack);
    
    return if ($class->_is_xinclude ($tag));
    
    if ( (not (defined $node->{replace} and $node->{replace})) and
	 (uc ($tag) ne 'AREA')     and 
	 (uc ($tag) ne 'BASE')     and 
	 (uc ($tag) ne 'BASEFONT') and 
	 (uc ($tag) ne 'BR')       and 
	 (uc ($tag) ne 'COL')      and 
	 (uc ($tag) ne 'FRAME')    and 
	 (uc ($tag) ne 'HR')       and 
	 (uc ($tag) ne 'IMG')      and 
	 (uc ($tag) ne 'INPUT')    and 
	 (uc ($tag) ne 'ISINDEX')  and 
	 (uc ($tag) ne 'LINK')     and 
	 (uc ($tag) ne 'META')     and 
	 (uc ($tag) ne 'PARAM') )
    {
	if (defined $node->{'omit-tag'})
	{
	    my $expression = $node->{'omit-tag'};
	    push @Petal::Canonicalizer::XML::Result, "<?if name=\"false:$expression\"?></$tag><?end?>";
	}
	else
	{
	    push @Petal::Canonicalizer::XML::Result, "</$tag>";
	}
    }
    
    my $repeat = $node->{repeat} || '0';
    my $condition = $node->{condition} || '0';
    my $define_slot = $node->{define_slot} || '0';
    push @Petal::Canonicalizer::XML::Result, map { '<?end?>' } 1 .. ($repeat+$condition+$define_slot);
    
    if (exists $node->{'on-error'})
    {
	my $expression = $node->{'on-error'};
	push @Petal::Canonicalizer::XML::Result, "<?endeval errormsg=\"$expression\"?>";
    }
}


1;
