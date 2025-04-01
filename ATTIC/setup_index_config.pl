#!/usr/bin/perl
#
# $Id: setup_index_config.pl,v 1.1 2003/12/21 22:01:06 ads Exp ads $
#
# $Log: setup_index_config.pl,v $
# Revision 1.1  2003/12/21 22:01:06  ads
# Initial revision
#
#

use strict;
use warnings;

my $script = $0; $script =~ s:^.*/::;

my $usage =  "Usage: $script [OPTIONS] FIELDS
OPTIONS:
   --fulltext        this is a fulltext indexing run
   --configdir DIR   config directory for version-independent files
   --targetdir DIR   local directory containing indexing files
   --db DB_KEY       database to be indexed (e.g. 'ast')
";

my $debug = 0;
my $fulltext = 0;
my $bin_dir = '/proj/ads/www/cgi/bin';
my @ostypes = qw( i486-linux x86_64-linux );
my %binaries = (cleanup => 'text_parser',
		stemmer => 'text_stemmer');
my $configdir = "$ENV{ADS_ABSCONFIG}";
my $targetdir = './config';
my $db = '';

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--fulltext') {
        $fulltext = 1; $db = 'ast';
    } elsif ($opt eq '--configdir') {
        $configdir = shift(@ARGV);
    } elsif ($opt eq '--targetdir') {
        $targetdir = shift(@ARGV);
    } elsif ($opt eq '--sourcedir') {
        $bin_dir = shift(@ARGV);
    } elsif ($opt eq '--db') {
        $db = shift(@ARGV);
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}

die "$script: $configdir not a directory\n$usage"
    unless (-d $configdir);
die "$script: $targetdir not a directory\n$usage"
    unless (-d $targetdir);
warn "$script: warning: no db_key specified\n"
    unless ($db);

# first copy the binary executables
foreach my $os (@ostypes) {
    foreach my $bin (sort keys %binaries) {
	my $source = "$bin_dir/$os/maint/$bin";
	my $dest = "$targetdir/$binaries{$bin}.$os";
	die "$script: error copying $source to $dest" 
	    if (system("cp -pvu $source $dest") );
    }
}

my @types = qw( trans kill kill_sens );
foreach my $field (@ARGV) {
    foreach my $type (@types) {
	my $source = "$configdir/${field}_$db.$type";
	my $dest = "$targetdir/$field.$type";
	unless (-f $source) {
	    $source = "$configdir/$field.$type";
	}
	next unless (-f $source);
	die  "$script: error copying $source to $dest" 
	    if (system("cp -pvu $source $dest"));
    }
}

# copy ancillary files
my @extras = ("$configdir/text.syn",
	      "$configdir/refwordstem.hash",
	      "$configdir/unicode.ent",
	      "$configdir/ocr.trans",
	      );
unless ($fulltext) {
    push(@extras, "$configdir/author.syn");
    push(@extras, "$configdir/xauthor.syn");
}

foreach my $extra (@extras) {
    die "$script: error $extra to $targetdir"
	if (system("cp -pvu $extra $targetdir"));
}


chdir($targetdir) or 
    die "$script: error setting current directory to $targetdir";

my $link = $fulltext ? 'full' : 'title';

# now create symbolic links between text and title files
foreach my $type (@types, 'syn') {
    die "$script: cannot link $link.$type to text.$type"
	if (system("ln -sv text.$type $link.$type"));
}


exit(0) if ($fulltext);

# now check and make sure that we have at least the following files:
my @files = qw( author.trans text.trans text.kill text.kill_sens 
		author.syn text.syn title.syn 
		refwordstem.hash unicode.ent );

foreach my $file (@files) {
    die "$script: file $targetdir/$file not found!"
	unless (-f $file);
}

exit 0;

