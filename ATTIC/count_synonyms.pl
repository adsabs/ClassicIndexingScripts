#!/usr/bin/perl
#
# Reads synonym file, and prints it out with
# the word count next to the word itself

use strict;
use Search::Dict;

my $usage = "$0 syn_file index_file[...] > syn_counts\n";

my $synfile = shift(@ARGV) or die $usage;
die  "$0: file $synfile not found\n$usage" unless (-f $synfile);
open(my $sh, $synfile) or die "$0: cannot read file $synfile: $!";

my @ih = ();

while (@ARGV) {
    my $indexfile = shift(@ARGV) or die $usage;
    die  "$0: file $indexfile not found\n$usage" unless (-f $indexfile);
    my $ih;
    open($ih, $indexfile) or die "$0: cannot read file $indexfile: $!";
    push(@ih, $ih);
}

die "$0: no index files specified\n$usage" unless ($#ih >= 0);
warn "$0: using ", scalar(@ih), " index files\n";

while (<$sh>) {
    if (/\A\s*\Z/ or /\A\s*\#/) {
	print;
	next;
    }
    s/\s*//g;
    my $tot = 0;
    foreach my $fh (@ih) {
	my $c = search_word_in_index($fh, $_);
	$tot += $c;
    }
    if ($tot eq 0) {
	print "# $_\t0\n";
    } else {
	print "$_\t$tot\n";
    }
}

sub search_word_in_index {
    my $fh = shift;
    my $w = shift;

    my $s = Search::Dict::look($fh,"$w\t",0,1);
    if ($s == -1) {
	return 0;
    }
    my $rec = <$fh>;
    unless ($rec) {
	return 0;
    }
    my ($o,$w, $c) = split(/\s+/,$rec);
    unless ($o and $c) {
	return 0;
    }
    unless (uc($o) eq uc($_)) {
	return 0;
    }
    # counts in index are in bytes
    $c /= 4;

    return $c;
}
