#!/usr/bin/perl
use warnings;
use strict;

use Petal;
use Petal::I18N;
use Petal::TranslationService::Gettext;
use File::Find;
use Cwd;
use open qw(:utf8);

my @files;
my @folders;

my $cwd = getcwd();
die("needs to be run from the root/templates folder!") unless($cwd =~ m/root\/templates$/);

my @langs = map { m!/([^/]*)\z!xm } grep { -d $_ } <../locale/*>;
mkdir $_ foreach @langs;

find(\&wanted, 'base');

foreach(sort @folders) { # sort to get base directories before subdirectories
    my $folder = $_;

    foreach(@langs) {
        my $langfolder = $folder;
        $langfolder =~ s/^base/$_/;
        print "Creating folder $langfolder\n";
        mkdir $langfolder;
    }
}

foreach(@files) {
    my $file = $_;
    foreach(@langs) {
        my $lang = $_;
        my $outfile = $file;
        $outfile =~ s/^base/$lang/;
        print "Translating $file to $lang in file $outfile\n";
        translate_file($file, $outfile, $lang);
    }
}

sub wanted {
    my $file = $File::Find::name;
    if ($file =~ m/\.xml/) {
        push(@files, $file);
        warn "got file: $file";
    }
    elsif(-d $_) {
        push(@folders, $file);
        warn "got folder $file";
    } 
}

sub translate_file {
    my ($infile, $outfile, $lang) = @_;

    $Petal::I18N::Domain = 'CiderWebmail';
    my $TranslationService = Petal::TranslationService::Gettext->new(
            domain => 'CiderWebmail',
            locale_dir => '../locale',
            target_lang => $lang,
        );

    open(INFILE, $infile);
    my $template = do { local $/; <INFILE> };
    close(INFILE);

    $Petal::TranslationService = $TranslationService;
    open(OUTFILE, "> $outfile") or die $!;
    print OUTFILE Petal::I18N->process($template);
    close(OUTFILE);

}
