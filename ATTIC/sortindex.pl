#!/usr/bin/perl
#
# $Id$
#
# Reads simple index and list files and creates a "canonical" version
# of them.  A canonical index file is one where all words are sorted and
# pointers to document IDs increase throughout the file; a canonical list
# file is one where all identifiers within a block are sorted and uniqued,
# and no empty blocks exist.
#
# $Log$
#
#

use strict;
use integer;
use warnings;

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script index_file [--debug] [--sort] [...]
$script creates a canonical version of index and list files.
A canonical index file is one where all words are sorted and
pointers to document IDs increase throughout the file
A canonical list file is one where all identifiers within a block 
are sorted and uniqued, and no empty blocks exist.
EOF
    ;

my $debug = 0;
my $dosort = 0;
my $SIZEOFLONG  = length(pack("N", 1));
while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--help') {
        die $usage;
    } elsif ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--sort') {
        $dosort = 1;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}

die $usage unless(@ARGV);
warn "$script: execution starting at ", scalar localtime(time), "\n";

while (@ARGV) {
    my $indexfile = shift;
    open(my $ifh, "sort $indexfile |") or
        die "$script: error reading index file $indexfile: $!";
    my $newindex = $indexfile . ".new";
    open(my $oifh, "> $newindex") or
        die "$script: error opening output file $newindex: $!";

    warn "$script: processing index file $indexfile at ",
    scalar localtime(time), "\n";

    # now open list file
    my $listfile = $indexfile; $listfile =~ s/\.index$/.list/;
    open(my $lfh, $listfile) or
        die "$script: cannot open list file $listfile: $!";
    my $newlist = $listfile . ".new";
    open(my $olfh, "> $newlist") or
        die "$script: cannot open output list file $newlist: $!";

    # now figure out what index has in it; it can have 3 or 4 columns
    # depending on whether it has a weight in it or not.  We do this
    # to be as flexible as possible
    my ($w,@records) = getIndexRecord($ifh);
    my ($bindex,$oindex);
    if (scalar(@records) == 2) {
	# columns are bytes, offset
	$bindex = 0;
	$oindex = 1;
    } elsif (scalar(@records) == 3) {
	# columns are weight, bytes, offset
	$bindex = 1;
	$oindex = 2;
    } else {
	die "$script: cannot deal with index with ", 1 + scalar(@records), 
	" columns\n";
    }

    my $newoffset = 0;

    while (defined($w)) {
	my $buff = '';
	my $bytes = $records[$bindex];
	my $offset = $records[$oindex];
	seek($lfh,$offset,0);
	read($lfh,$buff,$bytes) or
	    die "$script: error reading $bytes bytes at offset $offset",
	    " from file $listfile: $!";
	if ($dosort) {
	    # the sort and uniquing below should be unnecessary for
	    # new indexes
	    my %saw = map { ($_,1) } unpack("N*",$buff);	
	    my $nbuff = pack("N*", sort { $a <=> $b } keys %saw);
	    my $nbytes = length($buff);
	    warn "$script: warning: removed duplicate ids in block for ",
	    "word \"$w\"\n" if ($nbytes != $bytes);
	    warn "$script: warning: ids for word \"$w\" were not sorted\n"
		if ($nbuff ne $buff);
	    $buff = $nbuff;
	    $records[$bindex] = $bytes = $nbytes;
	}
	print $olfh $buff or
	    die "$script: error writing $bytes bytes to file $newlist: $!";
	$records[$oindex] = $newoffset;
	print $oifh join("\t", $w, @records), "\n" or
	    die "$script: error writing to file $newindex: $!";
	$newoffset += $bytes;
	($w,@records) = getIndexRecord($ifh);
    }

    close($ifh);
    close($lfh);
    close($oifh);
    close($olfh);

    # now rename index and list files
    rename($indexfile,"$indexfile.old") or
        die "$script: cannot rename file $indexfile to $indexfile.old: $!";
    rename($listfile,"$listfile.old") or
        die "$script: cannot rename file $listfile to $listfile.old: $!";
    rename($newindex,$indexfile) or
        die "$script: cannot rename file $newindex to $indexfile: $!";
    rename($newlist,$listfile) or
        die "$script: cannot rename file $newlist to $listfile: $!";
}

sub getIndexRecord {
    my $fh = shift;
    my $r = <$fh>;
    return () unless (defined($r));
    chop($r);
    split(/\t+/,$r);
}
