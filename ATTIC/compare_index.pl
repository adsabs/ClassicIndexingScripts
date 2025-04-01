#!/usr/bin/perl
#
# $Id$
#
# ./compare_index.pl --full --bytes --idfile /proj/ads/abstracts/ast/load/current/bib2accno.list ./author.index /proj/ads/abstracts/ast/load/current/author.index >! author.diff
#
# $Log$
#
#

use strict;
use warnings;
use integer;

(my $script = $0) =~ s:^.*/::;

my $checkwords = 1;
my $checksyns  = 1;
my $bytes = 0;
my $partial = 0;
my $debug = 0;
my $full = 0;
my $idfile = 'bib2accno.list';

my $usage = "Usage: $script [OPTIONS] index1 index2
OPTIONS: 
  --debug         print debugging information
  --bytes         index file contains byte offsets
  --full          output full list of differing records from list file
  --partial       this is a partial index (lacks score columns)
  --words-only    output only entries for words (not synonyms)
  --syns-only     output only entries for synonyms (not words)
  --idfile FILE   use line-to-id file FILE (default: bib2accno.list)
E.g. $script --full author.index ../author.index
";

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--words-only') {
	$checksyns = 0;
    } elsif ($opt eq '--syns-only' or $opt eq '--synonyms-only') {
	$checkwords = 0;
    } elsif ($opt eq '--partial') {
	$partial = 1;
    } elsif ($opt eq '--bytes') {
	$bytes = 1;
    } elsif ($opt eq '--help') {
	die $usage;
    } elsif ($opt eq '--debug') {
	$debug = 1;
    } elsif ($opt eq '--full') {
	$full = 1;
    } elsif ($opt eq '--idfile') {
	$idfile = shift(@ARGV) || '';
    } else {
	die $usage;
    }
}

die "$script: idfile $idfile not found!" unless (-f $idfile);
my $idmap = init_idfile($idfile) or
    die "$script: error opening id file $idfile: $!";

die $usage if ($#ARGV < 1);

my $index1 = shift(@ARGV) or die $usage;
$index1 .= ".index" unless ($index1 =~ /\.index$/);
die "$script: index file $index1 not found" unless (-f $index1);
open(my $ifh1, $index1) or die "$script: cannot open file $index1: $!";

my $index2 = shift(@ARGV) or die $usage;
$index2 .= ".index" unless ($index2 =~ /\.index$/);
die "$script: index file $index2 not found" unless (-f $index2);
open(my $ifh2, $index2) or die "$script: cannot open file $index2: $!";

my $list1 = $index1;
$list1 =~ s/\.index$//;
$list1 .= ".list";
die "$script: list file $list1 not found" unless (-f $list1);
open(my $lfh1, $list1) or die "$script: cannot open file $list1: $!";

my $list2 = $index2;
$list2 =~ s/\.index$//;
$list2 .= ".list";
die "$script: list file $list2 not found" unless (-f $list2);
open(my $lfh2, $list2) or die "$script: cannot open file $list2: $!";

my $n1 = 0;
my $n2 = 0;
my $mismatch = 0;
my $unmatch1 = 0;
my $unmatch2 = 0;
my $w1;
my $w2;
$n1++ if (defined($w1 = readrecord($ifh1)));
$n2++ if (defined($w2 = readrecord($ifh2)));

while (defined($w1) or defined($w2)) {
    if (not defined($w1)) {
	# we have exhausted entries from index1
	print "> ", printrecord($w2);
	$unmatch2++;
	warn "exhausted records from index1: $w2\n" if ($debug);
	$n2++ if (defined($w2 = readrecord($ifh2)));
    } elsif (not defined($w2)) {
	# we have exhausted entries from index2
	print "< ", printrecord($w1);
	$unmatch1++;
	warn "exhausted records from index2: $w1\n" if ($debug);
	$n1++ if (defined($w1 = readrecord($ifh1)));
    } else { 
	# we still have entries from both files, compare them
	my $test = cmprecord($w1, $w2);
	if ($test < 0) {
	    # get stuff from first file
	    if ($full) {
		printfull('words', $w1, $lfh1, undef, $lfh2) 
		    if ($checkwords and $w1->[1]);
		printfull('syns',  $w1, $lfh1, undef, $lfh2) 
		    if ($checksyns and $w1->[3]);
	    } else {
		print "< ", printrecord($w1);
	    }
	    $unmatch1++;
	    warn "unmatched record from index1: $w1\n" if ($debug);
	    $n1++ if (defined($w1 = readrecord($ifh1)));
	} elsif ($test > 0) {
	    # get stuff from second file
	    if ($full) {
		printfull('words', undef, $lfh1, $w2, $lfh2) 
		    if ($checkwords and $w2->[1]);
		printfull('syns',  undef, $lfh1, $w2, $lfh2) 
		    if ($checksyns and $w2->[3]);
	    } else {
		print "> ", printrecord($w2);
	    }
	    $unmatch2++;
	    warn "unmatched record from index2: $w2\n" if ($debug);
	    $n2++ if (defined($w2 = readrecord($ifh2)));
	} else {
	    # check if index entries agree
	    if ($checkwords and $w1->[1] != $w2->[1]) {
		warn "mismatched words from index1 and index2:\n\t",
		join(" ",@{$w1}), "\n\t", join(" ", @{$w2}), "\n" if ($debug);
		if ($full) {
		    printfull('words', $w1, $lfh1, $w2, $lfh2)
		} else {
		    print "< ", printrecord($w1);
		    print "> ", printrecord($w2);
		}
		$mismatch++;
	    } 
	    if ($checksyns and $w1->[3] != $w2->[3]) {
		warn "mismatched synonyms from index1 and index2:\n\t",
		join(" ",@{$w1}), "\n\t", join(" ", @{$w2}), "\n" if ($debug);
		if ($full) {
		    printfull('syns', $w1, $lfh1, $w2, $lfh2)
		} else {
		    print "< ", printrecord($w1);
		    print "> ", printrecord($w2);
		}
		$mismatch++;
	    }
	    # read both files
	    $n1++ if (defined($w1 = readrecord($ifh1)));
	    $n2++ if (defined($w2 = readrecord($ifh2)));
	}
    }
}

warn "$script: read $n1 records from file $index1 ($unmatch1 unmatched)\n";
warn "$script: read $n2 records from file $index2 ($unmatch2 unmatched)\n";
warn "$script: found $mismatch mismatches\n";

sub printfull {
    my $empty = [ '', 0, 0, 0, 0 ];
    my $type = shift;
    my $r1 = shift || $empty;
    my $lfh1 = shift;
    my $r2 = shift || $empty;
    my $lfh2 = shift;
    my $header = $r1->[0] || $r2->[0];
    my (@ids1, @ids2);

    if ($type eq 'words') {
	print $header, ": words: ", $r1->[1], " vs. ", $r2->[1], "\n";
	@ids1 = get_list_ids($lfh1, $r1->[2], $r1->[1]) if ($r1->[1]);
	@ids2 = get_list_ids($lfh2, $r2->[2], $r2->[1]) if ($r2->[1]);
    } elsif ($type eq 'syns') {
	print $header, ": syns: ", $r1->[3], " vs. ", $r2->[3], "\n";
	@ids1 = get_list_ids($lfh1, $r1->[4], $r1->[3]) if ($r1->[3]);
	@ids2 = get_list_ids($lfh2, $r2->[4], $r2->[3]) if ($r2->[3]);
    } else {
	die "$script: unknown term type '$type'";
    }

    my $id1 = shift(@ids1);
    my $id2 = shift(@ids2);
    while (defined($id1) or defined($id2)) {
	my $test = ($id1 || 0) <=> ($id2 || 0);
	if (not defined($id2)) {
	    warn "id2 not defined, printing id1: $id1\n" if ($debug);
	    print ">\t", id2doc($idmap, $id1);
	    $id1 = shift(@ids1);
	} elsif (not defined($id1)) {
	    warn "id1 not defined, printing id2: $id2\n" if ($debug);
	    print "<\t", id2doc($idmap, $id2);
	    $id2 = shift(@ids2);
	} elsif ($test < 0) {
	    warn "id1 less than id2, printing id1: $id1 ($id2)\n" if ($debug);
	    print ">\t", id2doc($idmap, $id1);
	    $id1 = shift(@ids1);
	} elsif ($test > 0) {
	    warn "id2 less than id1, printing id2: $id2 ($id1)\n" if ($debug);
	    print "<\t", id2doc($idmap, $id2);
	    $id2 = shift(@ids2);
	} else {
	    warn "id1 equal to id2, printing id1 and id2: $id2\n" if ($debug);
	    print "=\t", id2doc($idmap, $id2);
	    $id1 = shift(@ids1);
	    $id2 = shift(@ids2);
	}
    }
    
}

sub get_list_ids {
    my $lfh = shift;
    my $p = shift;
    my $c = shift;
    my $buff;

    if ($bytes) {
	$p *= 4;
	$c *= 4;
    }
    seek($lfh,$p,0);
    read($lfh,$buff,$c) or
	die "$script: cannot read $c bytes from list file: $!";
    return unpack("N*",$buff);
}

sub read_ids {
    my $fh = shift;
    my @ids = ();
    local $_;

    while (<$fh>) {
        my ($id,$accno) = split;
        next unless ($id and $id =~ /[a-zA-Z]/);
	push(@ids,$id);
    }

    return \@ids;
}

sub init_idfile {
    my $file = shift;
    open(my $fh, $file) or return undef;
    my $size = -s $file;

    # first like contains line count
    my $line = <$fh>;
    my $offs = length($line);
    $line =~ s/^\s+|\s+$//g;
    my ($count,$bytes) = split(/\s+/,$line);
    my $reclen = ($size - $offs) / $count;

    return { fh => $fh, reclen => $reclen, count => $count, offs => $offs };
}

sub id2doc {
    my $map = shift;
    my $fh = $map->{fh};
    my @docs;

    while (@_) {
        my $lineno = shift;
	my $line;
	if ($lineno < 0 or $lineno > $map->{count}) {
	    warn "$script: bad line number \"$lineno\" found\n";
	    $line = "XXXXXXXXXXXXXXXXXXX\n";
	} else {
	    my $pos = $map->{offs} + $lineno * $map->{reclen};
	    seek($fh,$pos,0);
	    $line = <$fh>;
	}
        push(@docs,$line);
    }

    return @docs;
}

sub readrecord {
    my $fh = shift;
    my $r = <$fh>;
    # check for line count at beginning of file
    $r = <$fh> if (defined($r) and $r =~ /^\s*\d+\s+\d+\s*$/);
    return undef unless (defined($r));

    chop($r);
    my ($term,@rest) = split(/\t/,$r);
    my ($w,$c,$p,$sw,$sc,$sp);
    if ($partial) {
	($c,$p,$sc,$sp) = @rest;
	$w = $sw = 'N/A';
    } else {
	($w,$c,$p,$sw,$sc,$sp) = @rest;
    }

    if ($bytes) {
	$c /= 4;
	$p /= 4;
	$sc /= 4;
	$sp /= 4;
    }

    return [ $term, $c, $p, $sc, $sp ];
}

sub cmprecord {
    my $r1 = shift;
    my $r2 = shift;
    
    return ($r1->[0] cmp $r2->[0]);
}

sub printrecord {
    my $r = shift;
    
    return join("\t", @{$r}) . "\n";
}
