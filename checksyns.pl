#!/usr/bin/perl
#
# $Id: addsyns.pl,v 1.1 2002/12/30 15:20:36 ads Exp ads $
#
# Adds synonyms to an index and list file
#
# $Log: addsyns.pl,v $
# Revision 1.1  2002/12/30 15:20:36  ads
# Initial revision
#
#


use strict;
use integer;
use warnings;

my $script = $0; $script =~ s:^.*/::;
my $usage = "$script [--groupnum] synfile [new_synfile]\n";
my $groupnum;
$groupnum = shift(@ARGV) if (@ARGV and $ARGV[0] eq '--groupnum');

my $synfile = shift(@ARGV) or die $usage;
my ($syngroups,$synnum,$synonyms) = readsyns($synfile) or
    die "$script: error reading synonym file $synfile: $!";
warn "$script: read ", $syngroups, " synonym groups from file $synfile\n";

my $output = shift(@ARGV) || '';
exit unless $output;
open(my $fh, ">$output") or die "$script: cannot open output file $output: $!";

for (my $i = 0; $i <= $syngroups; $i++) {
    my $sp = $synonyms->[$i];
    next unless ($sp);
    if ($groupnum) { 
	print $fh map { $i, "\t", $_, "\n" } @$sp;
    } else {
	print $fh map { $_, "\n" } @$sp;
    }
    print $fh "\n";
}


sub readsyns {
    my $file = shift;
    return () unless (-f $file);
    open(my $fh, $file) or return ();
    my %groupnums = ();
    my @syngroups = ();
    my $groupno = 1;
    my %currgroup = ();

    while (my $word = <$fh>) {
	next if ($word =~ /^\s*\#/); # skip comment lines
	$word =~ s/^\s+|\s+$//g;     # kill newline, leading blanks
	$word =~ tr/a-z/A-Z/;        # convert everything to upper case
	if ($word) {
	    # add to current group of synonyms
	    if ($groupnums{$word}) {
		if ($groupnums{$word} eq $groupno) {
		    warn "$script: warning: duplicate entry for word $word ",
		    "in group $groupno, please fix\n";
		} else {
		    warn "$script: warning: word \"$word\" already in syn ",
		    "group ", $groupnums{$word}, " ignoring second entry\n";
		}
	    } else {
		$groupnums{$word} = $groupno;
		$currgroup{$word}++;
	    }
	} else { 
	    # it's a new group of synonyms, bump group number
	    if (%currgroup) {
		$syngroups[$groupno] = [ sort keys %currgroup ];
		%currgroup = ();
		$groupno++;
	    }
	}
    }
    
    # add last one...
    $syngroups[$groupno] = [ sort keys %currgroup ] if %currgroup;
    
    return ($groupno,\%groupnums,\@syngroups);
}

