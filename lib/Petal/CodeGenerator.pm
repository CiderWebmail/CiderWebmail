package Petal::CodeGenerator::Decode;
use strict;
use warnings;
use base qw /MKDoc::XML::Decode/;


##
# $class->process ($xml);
# -----------------------
# Expands the entities &apos; &quot; &gt; &lt; and &amp;
# into their ascii equivalents.
##
sub process
{
    (@_ == 2) or warn "MKDoc::XML::Encode::process() should be called with two arguments";
    
    my $self = shift;
    my $data = join '', @_;
    $data    =~ s/&(#?[0-9A-Za-z]+)\\;/$self->entity_to_char ($1)/eg;
    
    return $data;
}


# ------------------------------------------------------------------
# Petal::CodeGenerator - Generates Perl code from canonical syntax
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# Description: This class parses a template in 'canonical syntax'
# (referred as the 'UGLY SYNTAX' in the manual) and generates Perl
# code that can be turned into a subroutine using eval().
# ------------------------------------------------------------------
package Petal::CodeGenerator;
use MKDoc::XML::Decode;
use strict;
use warnings;
use Carp;

our $PI_RE = '^<\?(?:\s|\r|\n)*(attr|include|var|if|condition|else|repeat|loop|foreach|for|eval|endeval|end|defslot).*?\?>$';
use vars qw /$petal_object $tokens $variables @code $indentLevel $token_name %token_hash $token $my_array/;


sub indent_increment
{
    my $class = shift;
    $Petal::CodeGenerator::indentLevel++;
}


sub indent_decrement
{
    my $class = shift;
    $Petal::CodeGenerator::indentLevel--;
}


sub indent
{
    my $class = shift;
    return $Petal::CodeGenerator::indentLevel;
}


# these _xxx_res primitives have been contributed by Fergal Daly <fergal@esatclear.ie>
# they speed up string construction a little bit
sub _init_res
{
    return '$res = ""';
}


sub _add_res
{
    my $class = shift;
    my $thing = shift;
    return qq{\$res .= $thing};
}


sub _final_res
{
    return q{$res};
}


sub _get_res
{
    return q{$res};
}


sub add_code
{
    my $class = shift;
    push(@code, "    " x $class->indent() . shift);
}


sub comp_expr
{
    my $self = shift;
    my $expr = shift;
    return "\$hash->get ('$expr')";
}


sub comp_expr_encoded
{
    my $self = shift;
    my $expr = shift;
    return "\$hash->get_encoded ('$expr')";
}


# $class->code_header();
# ----------------------
# This generates the beginning of the anonymous subroutine.
sub code_header
{
    my $class = shift;
    $class->add_code("\$VAR1 = sub {");
    $class->indent_increment();
    $class->add_code("my \$hash = shift;");
    $class->add_code("my ".$class->_init_res.";");
    $class->add_code('local $^W = 0;') unless $Petal::WARN_UNINIT;
}


# $class->code_footer();
# ----------------------
# This generates the tail of the anonymous subroutine
sub code_footer
{
    my $class = shift;
    $class->add_code("return ". $class->_final_res() .";");
    $class->indent_decrement();
    $class->add_code("};");
}


# $class->process ($data_ref, $petal_object);
# -------------------------------------------
# This (too big) subroutine converts the canonicalized template
# data into Perl code which is ready to be evaled and executed.
sub process
{
    my $class = shift;
    my $data_ref = shift;
    
    local $petal_object = shift || die "$class::" . "process: \$petal_object was not defined";
    
    local $tokens = $class->_tokenize ($data_ref);
    local $variables = {};
    local @code = ();
    local $Petal::CodeGenerator::indentLevel = 0;
    local $token_name = undef;
    local %token_hash = ();
    local $token = undef;
    local $my_array = {};
    
    $class->code_header();

    foreach $token (@{$tokens})
    {
        if ($token =~ /$PI_RE/s)
        {
	    ($token_name) = $token =~ /$PI_RE/s;
	    my @atts1 = $token =~ /(\S+)\=\"(.*?)\"/gos;
	    my @atts2 = $token =~ /(\S+)\=\'(.*?)\'/gos;
	    %token_hash = (@atts1, @atts2); 
	    foreach my $key (%token_hash)
	    {
		$token_hash{$key} = $class->_decode_backslash_semicolon ($token_hash{$key})
		    if (defined $token_hash{$key});
	    }
	    
          CASE:
            for ($token_name)
	    {
                /^attr$/      and do { $class->_attr;    last CASE };
                /^include$/   and do { $class->_include; last CASE };
		/^var$/       and do { $class->_var;     last CASE };
		/^if$/        and do { $class->_if;      last CASE };
		/^condition$/ and do { $class->_if;      last CASE };
                /^else$/      and do { $class->_else;    last CASE };
		/^repeat$/    and do { $class->_for;     last CASE };
		/^loop$/      and do { $class->_for;     last CASE };
		/^foreach$/   and do { $class->_for;     last CASE };
		/^for$/       and do { $class->_for;     last CASE };
		/^eval$/      and do { $class->_eval;    last CASE };
		/^endeval$/   and do { $class->_endeval; last CASE };
		/^defslot$/   and do { $class->_defslot; last CASE };
		
		/^end$/ and do
                {
                    my $idt = $class->indent();
		    delete $my_array->{$idt};
                    $class->indent_decrement();
                    $class->add_code("};");
                    last CASE;
                };
	    }
	}
	else
	{
            my $string = quotemeta ($token);
#            $string =~ s/\@/\\\@/gsm;
#            $string =~ s/\$/\\\$/gsm;
#            $string =~ s/\n/\\n/gsm;
#            $string =~ s/\n//gsm;
#            $string =~ s/\"/\\\"/gsm;
            $class->add_code($class->_add_res( '"' . $string . '";'));
        }
    }
    
    $class->code_footer();
    return join "\n", @code;
}


# $class->_include;
# -----------------
# process a <?include file="/foo/blah.html"?> file
sub _include
{
    my $class = shift;
    my $file  = $token_hash{file};
    my $path  = $petal_object->_include_compute_path ($file);
    my $lang  = $petal_object->language();
    $class->add_code ($class->_add_res ("do {"));
    $class->indent_increment();

    my $included_from = $petal_object->_file();
    $included_from =~ s/\#.*$//;

    $class->add_code ("do {");
    $class->indent_increment();

    $class->add_code ("my \$new_hash = \$hash->new();");
    $class->add_code ("\$new_hash->{__included_from__} = '$included_from';");

    (defined $lang and $lang) ?
        $class->add_code ("my \$res = eval { Petal->new (file => '$path', lang => '$lang')->process (\$new_hash) };") :
	$class->add_code ("my \$res = eval { Petal->new ('$path')->process (\$new_hash) };");
    
    $class->add_code ("\$res = \"<!--\\n\$\@\\n-->\" if (defined \$\@ and \$\@);");
    $class->add_code ("\$res;");
    $class->indent_decrement();
    $class->add_code ("} || '';");

    $class->indent_decrement();
    $class->add_code ("};");
}


# $class->_defslot;
# ---------------------
# process a <?defslot name="blah"?> statement
sub _defslot
{
    my $class = shift;
    my $variable = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'name' attribute is not defined";
   
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    $variable =~ s/\'/\\\'/g;

    $class->add_code ("do {");
    $class->indent_increment();

    $class->add_code ("my \$tmp = undef;");
    $class->add_code ("\$hash->{__included_from__} && do {");
    $class->indent_increment();

    $class->add_code ("my \$path = \$hash->{__included_from__} . '#$variable';");
    $class->add_code ("my \$new_hash = \$hash->new();");
    $class->add_code ("delete \$new_hash->{__included_from__};");

    my $lang  = $petal_object->language();
    (defined $lang and $lang) ?
        $class->add_code ("\$tmp = eval { Petal->new (file => \$path, lang => '$lang')->process (\$new_hash) };") :
	$class->add_code ("\$tmp = eval { Petal->new (\$path)->process (\$new_hash) };");

    $class->indent_decrement();
    $class->add_code ("};");

    $class->add_code ("if (\$tmp) {");
    $class->indent_increment();

    $class->add_code ( $class->_add_res ("\$tmp") );
    $class->indent_decrement();

    $class->add_code ( "} else {" );
    $class->indent_increment();
}
    

# $class->_var;
# -------------
# process a <?var name="blah"?> statement
sub _var
{
    my $class = shift;
    my $variable = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    $variable =~ s/\'/\\\'/g;
    $class->add_code ( $class->_add_res (('do {')) );
    $class->indent_increment();
    $class->add_code ('my $res = ' . $class->comp_expr_encoded ($variable) . ';');
    $class->add_code ('(defined $res) ? $res : "";');
    $class->indent_decrement();
    $class->add_code ('};');
}


# $class->_if;
# ------------
# process a <?if name="blah"?> statement
sub _if
{
    my $class = shift;
    my $variable = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'name' attribute is not defined";
		    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    $variable =~ s/\'/\\\'/g;
    $class->add_code("if (".$class->comp_expr($variable).") {");
    $class->indent_increment();
}


# $class->_eval;
# -------------------
# process a <?eval?> statement
sub _eval
{
    my $class = shift;
    $class->add_code($class->_add_res("eval {"));    
    $class->indent_increment();
    $class->add_code("my " . $class->_init_res() .";");
    $class->add_code("local %SIG;");
    $class->add_code("\$SIG{__DIE__} = sub { \$\@ = shift };");
}


# $class->_endeval;
# -----------------
# process a <?endeval errormsg="..."?> statement
sub _endeval
{   
    my $class = shift;
    my $variable = $token_hash{'errormsg'} or
       confess "Cannot parse $token : 'errormsg' attribute is not defined";
    
    $class->add_code("return " . $class->_get_res() . ";");
    $class->indent_decrement();
    $class->add_code("} || '';");
    
    $class->add_code("if (defined \$\@ and \$\@) {");
    $class->indent_increment();

    $variable =~ s/\&/&amp;/g;
    $variable =~ s/\</&lt;/g;
    $variable =~ s/\>/&gt;/g;
    $variable =~ s/\"/&quot;/g;
    $variable = quotemeta ($variable);
    $class->add_code($class->_add_res("\"$variable\";"));
    $class->indent_decrement();
    $class->add_code("}");
}


# $class->_attr;
# --------------
# process a <?attr name="blah"?> statement
sub _attr
{
    my $class = shift;
    my $attribute = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    my $variable = $token_hash{value} or
        confess "Cannot parse $token : 'value' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'value' attribute is not defined";
    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    $variable =~ s/\'/\\\'/g;
    $class->add_code('{');
    $class->indent_increment();
    $class->add_code ("my \$value = " . $class->comp_expr_encoded($variable) . ";");
    $class->add_code ("if (defined(\$value)) {");
    # $class->add_code ("if (defined(\$value) and length(\$value)) {");
    $class->indent_increment();
    $class->add_code ($class->_add_res (qq {"$attribute=\\"\$value\\""}) );
    $class->indent_decrement();
    $class->add_code ("}");
    $class->indent_decrement();
    $class->add_code ("}");
}


# $class->_else;
# --------------
# process a <?else name="blah"?> statement
sub _else
{
    my $class = shift;
    $class->indent_decrement();
    $class->add_code("}");
    $class->add_code("else {");
    $class->indent_increment();
}


# $class->_for;
# -------------
# process a <?for name="some_list" as="element"?> statement
sub _for
{
    my $class = shift;
    my $variable = $token_hash{name} or
    confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
    confess "Cannot parse $token : 'name' attribute is not defined";
    
    $variable =~ s/^\s+//;
    my $as;
    ($as, $variable) = split /\s+/, $variable, 2;
    
    (defined $as and defined $variable) or
        confess "Cannot parse $token : loop name not specified";
    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    my $idt = $class->indent(); 
    $variable =~ s/\'/\\\'/g;
    unless (defined $my_array->{$idt})
    {
	$class->add_code("my \@array = \@{".$class->comp_expr($variable)."};");
	$my_array->{$idt} = 1;
    }
    else
    {
	$class->add_code("\@array = \@{".$class->comp_expr($variable)."};");
    }

        
    $class->add_code ("for (my \$i=0; \$i < \@array; \$i++) {");
    $class->indent_increment();
    $class->add_code ("my \$hash   = \$hash->new();");
    
    # compute various might-be-useful variables
    $class->add_code ("my \$number = \$i + 1;");
    $class->add_code ("my \$odd    = \$number % 2;");
    $class->add_code ("my \$even   = \$i % 2;");
    $class->add_code ("my \$start  = (\$i == 0);");
    $class->add_code ("my \$end    = (\$i == \$#array);");
    $class->add_code ("my \$inner  = (\$i and \$i < \@array);");
    
    # backwards compatibility
    $class->add_code ("\$hash->{__count__}    = \$number;");
    $class->add_code ("\$hash->{__is_first__} = \$start;");
    $class->add_code ("\$hash->{__is_last__}  = \$end;");
    $class->add_code ("\$hash->{__is_inner__} = \$inner;");
    $class->add_code ("\$hash->{__even__}     = \$even;");
    $class->add_code ("\$hash->{__odd__}      = \$odd;");
    
    # new repeat style object
    $class->add_code ("\$hash->{repeat} = {");
    $class->indent_increment();
    $class->add_code ("index  => \$i,");
    $class->add_code ("number => \$number,");
    $class->add_code ("even   => \$even,");
    $class->add_code ("odd    => \$odd,");
    $class->add_code ("start  => \$start,");
    $class->add_code ("end    => \$end,");
    $class->add_code ("inner  => \$inner,");
    $class->add_code ("};");
    $class->indent_decrement();
    
    $class->add_code ("\$hash->{'$as'} = \$array[\$i];");
}


# $class->_tokenize ($data_ref);
# ------------------------------
# Returns the data to process as a list of tokens:
# ( 'some text', '<% a_tag %>', 'some more text', '<% end-a_tag %>' etc.
sub _tokenize
{
    my $self = shift;
    my $data_ref = shift;
    
    my @tags  = $$data_ref =~ /(<\?.*?\?>)/gs;
    my @split = split /(?:<\?.*?\?>)/s, $$data_ref;
    
    my $tokens = [];
    while (@split)
    {
        push @{$tokens}, shift (@split);
        push @{$tokens}, shift (@tags) if (@tags);
    }
    push @{$tokens}, (@tags);
    return $tokens;
}


sub _decode_backslash_semicolon
{
    my $class = shift;
    my $data  = shift;
    
    my $decode = new Petal::CodeGenerator::Decode ('xml');
    return $decode->process ($data);
}


1;
