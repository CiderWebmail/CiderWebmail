# ------------------------------------------------------------------
# Petal::Functions - Helper functions for the Petal.pm wrapper
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# Description: This class parses a template in 'canonical syntax'
# (referred as the 'UGLY SYNTAX' in the manual) and generates Perl
# code that can be turned into a subroutine using eval().
# ------------------------------------------------------------------
package Petal::Functions;
use strict;
use warnings;


# find_filepath ($filename, @paths);
# ----------------------------------
# Finds the filepath for $filename in @paths
# and returns it.
sub find_filepath
{
    my $filename = shift;
    for (@_)
    {
	s/\/$//;
	return $_ if (-e "$_/$filename");
    }
}


# find_filename ($language, @paths);
# ----------------------------------
# Finds the filename for $language in @paths.
# For example, if $language is 'fr-CA' it might return
#
# fr-CA.html
# fr-CA.xml
# fr.html
# en.html
sub find_filename
{
    my $lang  = shift;
    my @paths = @_;
    
    while (defined $lang)
    {
	foreach my $path (@paths)
	{
	    my $filename = exists_filename ($lang, $path);
	    defined $filename and return $filename;
	}
	
	$lang = parent_language ($lang);
    }
    
    return;
}


# parent_language ($lang);
# ------------------------
# Returns the parent language for $lang, i.e.
# 'fr-CA' => 'fr' => $Petal::LANGUAGE => undef.
#
# $DEFAULT is set to 'en' by default but that can be changed, e.g.
#   local $Petal::LANGUAGE = 'fr' for example
sub parent_language
{
    my $lang = shift;
    $lang =~ /-/ and do {
	($lang) = $lang =~ /^(.*)\-/;
	return $lang;
    };
    
    $lang eq $Petal::LANGUAGE and return;
    return $Petal::LANGUAGE;
}


# exists_filename ($language, $path);
# -----------------------------------
# looks for a file that matches $langage.<extension> in $path
# if the file is found, returns the filename WITH its extension.
#
# example:
#
#   # $filename will be either 'en-US.html, en-US.xml, ... or 'undef'.
#   my $filename = exists_filename ('en-US', './scratch');
sub exists_filename
{
    my $language = shift;
    my $path = shift;
    
    opendir DD, $path;
    my @grep = grep /^$language\./, readdir (DD);
    closedir DD;
    
    return shift (@grep);
}


1;


__END__
