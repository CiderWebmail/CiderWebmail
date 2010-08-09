# ------------------------------------------------------------------
# Petal::Cache::Memory - Caches generated subroutines in memory.
# ------------------------------------------------------------------
# Author: Jean-Michel Hiver
# Description: A simple cache module to avoid re-compiling the Perl
# code from the Perl data at each request.
# ------------------------------------------------------------------
package Petal::Cache::Memory;
use strict;
use warnings;
use Carp;


our $FILE_TO_SUBS  = {};
our $FILE_TO_MTIME = {};


sub sillyness
{
    + $Petal::INPUT && $Petal::OUTPUT;
}


# $class->get ($file);
# --------------------
# Returns the cached subroutine if its last modification time
# is more recent than the last modification time of the template,
# returns undef otherwise
sub get
{
    my $class = shift;
    my $file  = shift;
    my $data  = shift;
    my $lang  = shift || '';
    my $key = $class->compute_key ($file, $lang);
    return $FILE_TO_SUBS->{$key} if ($class->is_ok ($file));
    return;
}


# $class->set ($file, $code);
# ---------------------------
# Sets the cached code for $file.
sub set
{
    my $class = shift;
    my $file  = shift;
    my $code  = shift;
    my $lang  = shift || '';
    my $key = $class->compute_key ($file, $lang);
    $FILE_TO_SUBS->{$key} = $code;
    $FILE_TO_MTIME->{$key} = $class->current_mtime ($file);
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
    return unless (defined $FILE_TO_SUBS->{$key});
    
    my $cached_mtime = $class->cached_mtime ($file);
    my $current_mtime = $class->current_mtime ($file);
    return $cached_mtime >= $current_mtime;
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
    return $FILE_TO_MTIME->{$key};
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
    
    my $key = $file . ";$lang" . ";INPUT=" . $Petal::INPUT . ";OUTPUT=" . $Petal::OUTPUT;
    return $key;
}


1;
