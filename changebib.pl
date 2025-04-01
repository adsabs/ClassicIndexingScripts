#!/usr/bin/perl
#
# Changes a bibcode in .dat files
#

use ADS::Environment;
use File::Find;

my $topdir = $ENV{ADS_ABSCONFIG} . '/links';
my $script = $0; $script =~ s:^.*/::;
my $usage = "Usage: $script [--topdir DIR] < changes.bibs\n";
my $verbose = 0;

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $s = shift(@ARGV);
    if ($s eq '--topdir') {
	$topdir = shift(@ARGV);
    } elsif ($s eq '--verbose') {
	$verbose++;
    } else {
	die "$script: unknown option $s\n", $usage;
    }
}

# read bibcode mappings
my %bibmap = ();
while (<>) {
    next unless /\S/;      # skip blank lines
    next if /^\s*#/;       # skip comments
    my ($old,$new) = split;
    next unless ($old and $new);
    $bibmap{$old} = $new;
}

die "$script: no bibcode mappings found!\n" unless (%bibmap);

find(\&changebibs, $topdir);

sub changebibs {

    return unless (/\.dat$/);
    warn "$script: considering file $File::Find::dir/$_\n" if ($verbose);

    open(my $fh, $_) or die "$script: cannot open input file $_: $!";
    my ($line,$buff,$changed);
    while (my $line = <$fh>) {
	if ($bibmap{substr($line,0,19)}) {
	    $changed++;
	    $buff .= $bibmap{substr($line,0,19)} . substr($line,19);
	} else {
	    $buff .= $line;
	}
    }
    return unless ($changed);
    warn "$script: found $changed changes in file $File::Find::dir/$_\n" 
	if ($verbose);

    undef($fh);
    if (-f "$_.new") {
	warn "$script: file $File::Find::dir/$_ exists already!\n";
	return;
    }
    open($fh, "> $_.new") or die "$script: cannot open input file $_.new: $!";
    print $fh $buff;
    undef($fh);

    warn "$script: modified $changed bibcodes in file $File::Find::dir/$_\n";

    my $f = $_; $f =~ s/\.dat//;
    foreach my $ext (qw( exe flt )) {
	warn "$script: warning: found file $File::Find::dir/$f.$ext\n"
	    if (-f "$f.$ext");
    }
}
