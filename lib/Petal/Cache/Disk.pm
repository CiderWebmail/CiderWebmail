# ------------------------------------------------------------------
# Petal::Cache::Disk - Caches generated code on disk.
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# Description: A simple cache module to avoid re-generating the Perl
# code from the template file every time
# ------------------------------------------------------------------
package Petal::Cache::Disk;
use strict;
use warnings;
use File::Spec;
use Digest::MD5 qw /md5_hex/;
use Carp;


# kill silly warnings
sub sillyness
{
    + $Petal::INPUT &&
    + $Petal::OUTPUT;
}


# local $Petal::Cache::Disk::TMP_DIR = <some_dir>
# defaults to File::Spec->tmpdir;
our $TMP_DIR = File::Spec->tmpdir;


# local $Petal::Cache::Disk::PREFIX = <some_prefix>
# defaults to 'petal_cache_'
our $PREFIX = 'petal_cache';


# $class->get ($file);
# --------------------
# Returns the cached data if its last modification time is more
# recent than the last modification time of the template
# Returns the code for template file $file, undef otherwise
sub get
{
    my $class = shift;
    my $file  = shift;
    my $lang  = shift || '';
    my $key   = $class->compute_key ($file, $lang);
    return $class->cached ($key) if ($class->is_ok ($file));
    return;
}


# $class->set ($file, $data);
# ---------------------------
# Sets the cached data for $file.
sub set
{
    my $class = shift;
    my $file  = shift;
    my $data  = shift;
    my $lang  = shift || '';
    my $key   = $class->compute_key ($file, $lang);
    my $tmp   = $class->tmp;
    {
	if ($] > 5.007)
	{
	    open FP, ">:utf8", "$tmp/$key" or ( Carp::cluck "Cannot write-open $tmp/$key" and return );
	}
	else
	{
	    open FP, ">$tmp/$key" or ( Carp::cluck "Cannot write-open $tmp/$key" and return );
	}
	
	print FP $data;
	close FP;
    }
}


# $class->is_ok ($file);
# ----------------------
# Returns TRUE if the cache is still fresh, FALSE otherwise.
sub is_ok
{
    my $class = shift;
    my $file  = shift;
    my $lang  = shift || '';
    
    my $key = $class->compute_key ($file, $lang);
    my $tmp = $class->tmp;    
    my $tmp_file = "$tmp/$key";
    return unless (-e $tmp_file);
    
    my $cached_mtime = $class->cached_mtime ($file);
    my $current_mtime = $class->current_mtime ($file);
    return $cached_mtime >= $current_mtime;
}


# $class->compute_key ($file);
# ----------------------------
# Computes a cache 'key' for $file, which should be unique.
# (Well, currently an MD5 checksum is used, which is not
# *exactly* unique but which should be good enough)
sub compute_key
{
    my $class = shift;
    my $file = shift;
    my $lang = shift || '';
    
    my $key = md5_hex ($file . ";$lang" . ";INPUT=" . $Petal::INPUT . ";OUTPUT=" . $Petal::OUTPUT);
    $key = $PREFIX . "_" . $Petal::VERSION . "_" . $key if (defined $PREFIX);
    return $key;
}


# $class->cached_mtime ($file);
# -----------------------------
# Returns the last modification date of the cached data
# for $file
sub cached_mtime
{
    my $class = shift;
    my $file = shift;
    my $lang = shift || '';
    my $key = $class->compute_key ($file, $lang);
    my $tmp = $class->tmp;
    
    my $tmp_file = "$tmp/$key";
    my $mtime = (stat($tmp_file))[9];
    return $mtime;
}


# $class->current_mtime ($file);
# ------------------------------
# Returns the last modification date for $file
sub current_mtime
{
    my $class = shift;
    my $file = shift;
    $file =~ s/#.*$//;
    my $mtime = (stat($file))[9];
    return $mtime;
}


# $class->cached ($key);
# ----------------------
# Returns the cached data for $key
sub cached
{
    my $class = shift;
    my $key = shift;
    my $tmp = $class->tmp;
    my $cached_filepath = $tmp . '/' . $key;
    
    (-e $cached_filepath) or return;

    my $res = undef;
    {
	if ($] > 5.007)
	{
	    open FP, "<:utf8", "$tmp/$key" or ( Carp::cluck "Cannot read-open $tmp/$key" and return );
	}
	else
	{
	    open FP, "<$tmp/$key" or ( Carp::cluck "Cannot read-open $tmp/$key" and return );
	}
	
	$res = join '', <FP>;
	close FP;
    }
    
    return $res;
}


# $class->tmp;
# ------------
# Returns the temp directory in which the cached data is kept.
sub tmp
{
    my $class = shift;
    $TMP_DIR ||= File::Spec->tmpdir;
    
    (-e $TMP_DIR) or confess "\$TMP_DIR '$TMP_DIR' does not exist";
    (-d $TMP_DIR) or confess "\$TMP_DIR '$TMP_DIR' is not a directory";
    $TMP_DIR =~ s/\/+$//;
    return $TMP_DIR;
}


1;
