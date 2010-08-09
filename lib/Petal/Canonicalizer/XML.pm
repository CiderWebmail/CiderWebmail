# ------------------------------------------------------------------
# Petal::Canonicalizer::XML - Builds an XML canonical Petal file
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
# ------------------------------------------------------------------
package Petal::Canonicalizer::XML;
use Petal::Hash::String;
use MKDoc::XML::Encode;
use strict;
use warnings;

use vars qw /@Result @NodeStack/;


# $class->process ($parser, $data_ref);
# -------------------------------------
# returns undef if $parser object (i.e. a Petal::Parser::XML object)
# could not parse the data which $data_ref pointed to.
#
# returns a reference to the canonicalized string otherwise.
sub process
{
    my $class = shift;
    my $parser = shift;
    my $data_ref = shift;
    $data_ref = (ref $data_ref) ? $data_ref : \$data_ref;
    
    # grab anything that's before the first '<' tag
    my ($header) = $$data_ref =~ /(^.*?)<(?!\?|\!)/sm;
    $$data_ref =~ s/(^.*?)<(?!\?|\!)/\</sm;
    
    # grab the <!...> tags which the parser is going to strip
    # in order to reinclude them afterwards
    # my @decls = $$data_ref =~ /(<!.*?>)/gsm;
    
    # take the existing processing instructions out and replace
    # them with temporary xml-friendly handlers
    my $pis = $class->_processing_instructions_out ($data_ref);
    
    local @Result = ();
    local @NodeStack = ();
    
    $parser->process ($class, $data_ref);
    
    $header ||= '';
    my $res = '';
    $res   .= $header unless ($Petal::CURRENT_INCLUDES > 1);
    $res   .= (join '', @Result);

    $class->_processing_instructions_in (\$res, $pis);
    
    return \$res;
}


# _processing_instructions_out ($data_ref);
# -----------------------------------------
#   takes the existing processing instructions (i.e. <? blah ?>)
#   and replace them with temporary xml-friendly handlers (i.e.
#   [-- NBXNBBJBNJNBJVNK --]
#
#   returns the <? blah ?> => [-- NBXNBBJBNJNBJVNK --] mapping
#   as a hashref
#
#   NOTE: This is because processing instructions are special to
#   HTML::Parser, XML::Parser etc. and it's easier to just handle
#   them separately
sub _processing_instructions_out
{
    my $class = shift;
    my $data_ref = shift;
    my %pis = map { $_ => $class->_compute_unique_string ($data_ref) } $$data_ref =~ /(<\?.*?\?>)/gsm;
    
    while (my ($key, $value) = each %pis) {
	$$data_ref =~ s/\Q$key\E/$value/gsm;
    }
    
    return \%pis;
}


# _processing_instructions_in ($data_ref, $pis);
# ----------------------------------------------
#   takes the processing instructions mapping defined in the $pis
#   hashref and restores the processing instructions in the data
#   pointed by $data_ref
sub _processing_instructions_in
{
    my $class = shift;
    my $data_ref = shift;
    my $pis = shift;
    while (my ($key, $value) = each %{$pis}) {
	$$data_ref =~ s/\Q$value\E/$key/gsm;
    }
}


# _compute_unique_string ($data_ref)
# ----------------------------------
#   computes a string which does not exist in $$data_ref
sub _compute_unique_string
{
    my $class = shift;
    my $data_ref = shift;
    my $string = '[-' . (join '', map { chr (ord ('a') + int rand 26) } 1..20) . '-]';
    while (index ($$data_ref, $string) >= 0)
    {
	$string = '[-' . (join '', map { chr (ord ('a') + int rand 26) } 1..20) . '-]';
    }
    return $string;
}


# $class->StartTag();
# -------------------
# Called for every start tag with a second parameter of the element type.
# It will check for special PETAL attributes like petal:if, petal:loop, etc...
# and rewrite the start tag into @Result accordingly.
#
# For example
#
#   <foo petal:if="blah">
#
# Is rewritten
#
#   <?petal:if name="blah"?><foo>...
sub StartTag
{
    Petal::load_code_generator(); # we will use it later
    
    my $class = shift;
    push @NodeStack, {};
    return if ($class->_is_inside_content_or_replace());
    
    my $tag = $_;
    ($tag) = $tag =~ /^<\s*((?:\w|\:|\-)*)/;
    my $att = { %_ };
    
    $class->_use_macro   ($tag, $att);
    $class->_on_error    ($tag, $att);
    $class->_define      ($tag, $att);
    $class->_define_slot ($tag, $att);
    $class->_condition   ($tag, $att);
    $class->_repeat      ($tag, $att);    
    $class->_is_xinclude ($tag) and $class->_xinclude ($tag, $att) and return;
    $class->_replace     ($tag, $att);
    
    my $petal = quotemeta ($Petal::NS);
    
    # if a petal:replace attribute was set, then at this point _is_inside_content_or_replace()
    # should return TRUE and this code should not be executed
    unless ($class->_is_inside_content_or_replace())
    {
	# for every attribute which is not a petal: attribute,
	# we need to convert $variable into <?petal:var name="variable"?>
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

        # processes the petal:attributes instruction	
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

	if (defined $att->{"$petal:omit-tag"})
	{
	    my $expression = $att->{"$petal:omit-tag"} || 'string:1';
	    $NodeStack[$#NodeStack]->{'omit-tag'} = $expression;
	    push @Result, (defined $att_str and $att_str) ?
	        "<?if name=\"false:$expression\"?><$tag $att_str><?end?>" :
		"<?if name=\"false:$expression\"?><$tag><?end?>";
	}
	else
	{
	    push @Result, (defined $att_str and $att_str) ? "<$tag $att_str>" : "<$tag>";
	}
	
	$class->_content ($tag, $att);
    }
}


# $class->EndTag();
# -----------------
# Called for every end tag with a second parameter of the element type.
# It will check in the @NodeStack to see if this end-tag also needs to close
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
    my $node = pop (@NodeStack);
    
    return if ($class->_is_xinclude ($tag));
    
    unless (defined $node->{replace} and $node->{replace})
    {
	if (exists $node->{'omit-tag'})
	{
	    my $expression = $node->{'omit-tag'};
	    push @Result, "<?if name=\"false:$expression\"?></$tag><?end?>";
	}
	else
	{
	    push @Result, "</$tag>";
	}	
    }
    
    my $repeat = $node->{repeat} || '0';
    my $condition = $node->{condition} || '0';
    my $define_slot = $node->{define_slot} || '0';
    push @Result, map { '<?end?>' } 1 .. ($repeat+$condition+$define_slot);

    unless (defined $node->{replace} and $node->{replace})
    {
	if (exists $node->{'on-error'})
	{
	    my $expression = $node->{'on-error'};
	    push @Result, "<?endeval errormsg=\"$expression\"?>";
	}
    }
}


# $class->Text();
# ---------------
# Called just before start or end tags.
# Turns all variables such as $foo:bar into <?petal var name=":foo bar"?>
sub Text
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    my $text = $_;
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
    push @Result, $text;
}


# _is_inside_content_or_replace();
# --------------------------------
# Returns TRUE if @NodeStack contains a node which has a
# 'content' or a 'replace' attribute set.
sub _is_inside_content_or_replace
{
    my $class  = shift;
    my $endtag = shift;
    my $tmp    = undef;
    $tmp = pop (@NodeStack) if ($endtag);
    
    # WHY do I have to do this?
    return 1 if (defined $tmp and $tmp->{'use-macro'});
    for (my $i=@NodeStack - 1; $i >= 0; $i--)
    {
	return 1 if ( defined $NodeStack[$i]->{'replace'}   or
		      defined $NodeStack[$i]->{'content'}   or
		      defined $NodeStack[$i]->{'use-macro'} );
    }
    push @NodeStack, $tmp if (defined $tmp);
    return;
}


# _split_expression ($expr);
# --------------------------
# Splits multiple semicolon separated expressions, which
# are mainly used for the petal:attributes attribute, i.e.
# would turn "href document.uri; lang document.lang; xml:lang document.lang"
# into ("href document.uri", "lang document.lang", "xml:lang document.lang")
sub _split_expression
{
    my $class = shift;
    my $expression = shift;
    my @tokens = map { (defined $_ and $_) ? $_ : () }
                 split /(\s|\r|\n)*(?<!\\)\;(\s|\r|\n)*/ms,
		 $expression;
    
    return map { s/^(\s|\n|\r)+//sm;
		 s/(\s|\n|\r)+$//sm;
		 ($_ eq '') ? () : $_ } @tokens;
}


# _condition;
# -----------
# Rewrites <tag petal:if="[expression]"> statements into
# <?petal:if name="[expression]"?><tag>
sub _on_error
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $petal = quotemeta ($Petal::NS);
    my $tag   = shift;
    my $att   = shift;
    my $expr  = delete $att->{"$petal:on-error"} || return;
    
    $expr = $class->_encode_backslash_semicolon ($expr);
    push @Result, "<?eval?>";
    $NodeStack[$#NodeStack]->{'on-error'} = $expr;
    return 1;
}


# _define;
# --------
# Rewrites <tag petal:define="[name] [expression]"> statements into
# canonical <?petal:var name=":set [name] [expression]"?>
sub _define
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $petal = $Petal::NS;
    my $tag   = shift;
    my $att   = shift;
    my $expr  = delete $att->{"$petal:set"}    ||
                delete $att->{"$petal:def"}    ||
                delete $att->{"$petal:define"} || return;
    
    $expr = $class->_encode_backslash_semicolon ($expr);
    push @Result, map { "<?var name=\"set: $_\"?>" } $class->_split_expression ($expr);
    return 1;
}


# _condition;
# -----------
# Rewrites <tag petal:if="[expression]"> statements into
# <?petal:if name="[expression]"?><tag>
sub _condition
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());

    my $petal = $Petal::NS;
    my $tag   = shift;
    my $att   = shift;
    my $expr  = delete $att->{"$petal:if"}        ||
                delete $att->{"$petal:condition"} || return;
    
    $expr = $class->_encode_backslash_semicolon ($expr);
    my @new = map { "<?if name=\"$_\"?>" } $class->_split_expression ($expr);
    push @Result, @new;
    $NodeStack[$#NodeStack]->{condition} = scalar @new;
    return 1;
}


# _define_slot;
# -----------
# Rewrites <tag petal:if="[expression]"> statements into
# <?petal:if name="[expression]"?><tag>
sub _define_slot
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());

    my $metal = $Petal::MT_NS;
    my $tag   = shift;
    my $att   = shift;
    my $expr  = delete $att->{"$metal:define-slot"} || return;
    
    $expr = $class->_encode_backslash_semicolon ($expr);
    my @new = map { "<?defslot name=\"__metal_slot__$_\"?>" } $class->_split_expression ($expr);
    push @Result, @new;
    $NodeStack[$#NodeStack]->{define_slot} = 2 * scalar @new;
    return 1;
}


# _repeat;
# --------
# Rewrites <tag petal:loop="[name] [expression]"> statements into
# <?petal:loop name="[name] [expression]"?><tag>
sub _repeat
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());

    my $petal = $Petal::NS;
    my $tag = shift;
    my $att = shift;
    my $expr = delete $att->{"$petal:for"}     ||
               delete $att->{"$petal:foreach"} ||
               delete $att->{"$petal:loop"}    ||
               delete $att->{"$petal:repeat"}  || return;
    
    my @exprs = $class->_split_expression ($expr);
    my @new = ();
    foreach $expr (@exprs)
    {
	$expr = $class->_encode_backslash_semicolon ($expr);
	push @new, "<?for name=\"$expr\"?>"
    }
    push @Result, @new;
    $NodeStack[$#NodeStack]->{repeat} = scalar @new;
    return 1;
}


# _replace;
# ---------
# Rewrites <tag petal:outer="[expression]"> as <?petal:var name="[expression]"?>
# All the descendent nodes of 'tag' will be skipped
sub _replace
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $petal = $Petal::NS;
    my $tag = shift;
    my $att = shift;
    my $expr = delete $att->{"$petal:replace"} ||
               delete $att->{"$petal:outer"}   || return;
    
    my @new = map {
	$_ = $class->_encode_backslash_semicolon ($_);
	"<?var name=\"$_\"?>";
    } $class->_split_expression ($expr);
    
    push @Result, @new;
    $NodeStack[$#NodeStack]->{replace} = 'true';
    return 1;
}


# _use_macro;
# -----------
# Rewrites <tag use-macro="something" as <?include file="something"?>
# All the descendent nodes of 'tag' will be skipped
sub _use_macro
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $metal = $Petal::MT_NS;
    
    my $tag = shift;
    my $att = shift;
    my $expr = delete $att->{"$metal:use-macro"} || return;
    
    push @Result, qq|<?include file="$expr"?>|;
    $NodeStack[$#NodeStack]->{'use-macro'} = 'true';
    return 1;
}


# _attributes;
# ------------
# Rewrites <?tag attributes="[name1] [expression]"?>
# as <tag name1="<?var name="[expression]"?>
sub _attributes
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $petal = $Petal::NS;   
    my $tag = shift;
    my $att = shift;
    my $expr = delete $att->{"$petal:att"}        ||
               delete $att->{"$petal:attr"}       ||
               delete $att->{"$petal:atts"}       ||
	       delete $att->{"$petal:attributes"} || return;
    
    foreach my $string ($class->_split_expression ($expr))
    {
	next unless (defined $string);
	next if ($string =~ /^\s*$/);
	my ($attr, $expr) = $string =~ /^\s*([A-Za-z_:][A-Za-z0-9_:.-]*)\s+(.*?)\s*$/;
        if (not defined $attr or not defined $expr)
        {
            warn "Attributes expression '$string' does not seem valid - Skipped";
            next;
        }
        
	$expr = $class->_encode_backslash_semicolon ($expr);
	$att->{$attr} = "<?attr name=\"$attr\" value=\"$expr\"?>";
    }

    return 1;
}


# _content;
# ---------
# Rewrites <tag petal:inner="[expression]"> as <tag><?petal:var name="[expression]"?>
# All the descendent nodes of 'tag' will be skipped
sub _content
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $petal = $Petal::NS;   
    my $tag = shift;
    my $att = shift;
    my $expr = delete $att->{"$petal:content"}  ||
               delete $att->{"$petal:contents"} ||
	       delete $att->{"$petal:inner"}    || return;
    my @new = map {
	$_ = $class->_encode_backslash_semicolon ($_);
	"<?var name=\"$_\"?>";
    } $class->_split_expression ($expr);
    push @Result, @new;
    $NodeStack[$#NodeStack]->{content} = 'true';
    return 1;
}


# _xinclude ($tag, $att);
# -----------------------
# Rewrites <xi:include href="../foo.xml" /> into
# <?include file="../foo.xml"?>.
sub _xinclude
{
    my $class = shift;
    return if ($class->_is_inside_content_or_replace());
    
    my $tag = shift;
    my $att = shift;
    
    if ($class->_is_xinclude ($tag))
    {
	# strip remaining Petal tags
	my $petal = quotemeta ($Petal::NS);
	$att = { map { $_ =~ /^$petal:/ ? () : $_ => $att->{$_} } keys %{$att} };
	
	my $expr = delete $att->{'href'};
	$expr = $class->_encode_backslash_semicolon ($expr);
	push @Result, "<?include file=\"$expr\"?>";
    }
    return 1;
}


# _is_xinclude ($tag);
# --------------------
# Returns TRUE if $tag is a Xinclude directive,
# FALSE otherwise.
sub _is_xinclude
{
    my $class = shift;
    my $tag = shift;
    my $xi = quotemeta ($Petal::XI_NS);
    return $tag =~ /^$xi:/
}


sub _encode_backslash_semicolon
{
    my $class = shift;
    my $data  = shift;
    $data =~ s/($MKDoc::XML::Encode::XML_Encode_Pattern)/&$MKDoc::XML::Encode::XML_Encode{$1}\\;/go;
    return $data;
}


1;


__END__
