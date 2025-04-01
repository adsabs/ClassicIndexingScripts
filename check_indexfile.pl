#!/usr/bin/perl

use strict;
#use warnings;
use integer;

my $script = $0;
my $bytes = 0;
my $sizeoflong = length(pack("N",0));
my $binrecsize = 5 * $sizeoflong;

my $usage = "Usage: $script [OPTIONS] index_file [...]
OPTIONS:
  --bytes         index file contains byte offsets
";

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--bytes') {
        $bytes = 1;
    } elsif ($opt eq '--help') {
        die $usage;
    } else {
        die $usage;
    }
}

while (@ARGV) {
    my $index = shift(@ARGV) or die $usage;
    $index .= ".index" unless ($index =~ /\.index$/);
    die "$script: index file $index not found" unless (-f $index);
    open(my $ifh, $index) or die "$script: cannot open file $index: $!";

    my $list = $index;
    $list =~ s/\.index$//;
    $list .= ".list";
    die "$script: list file $list not found" unless (-f $list);
    my $listsize = (-s $list);

    my $binary = ($index =~ /_pairs.index$/) ? 1 : 0;
    my $nrecs;
    if ($binary) {
	$nrecs = (-s $index) / $binrecsize;
    } else {
	my $f = <$ifh>; $f =~ s/^\s+|\s+//g;
	($nrecs) = split(/\s+/,$f);
    }

    print STDERR "checking contents of ", 
    (($binary) ? "binary" : "ascii"), 
    " index $index ($nrecs records) vs. $list ($listsize bytes)...";
    my $status = ($binary) ? check_binary($ifh,$listsize) :
	check_ascii($ifh,$listsize);
    print STDERR (($status) ? "ERROR!\n" : "OK\n");
}

sub check_binary {
    my $fh = shift;
    my $size = shift;
    my $buff;

    while (read($fh,$buff,$binrecsize)) {
	my ($len,$off) = (unpack("N*",$buff))[3,4];
	if ($bytes) {
	    no integer;
	    if (int($len / 4) != ($len / 4) or
		int($off / 4) != ($off / 4)) {
		print STDERR "error reading record at position ", 
		tell($fh) - $binrecsize, ": ";
		printf STDERR "%u %u %u %u %u\n", unpack("N*",$buff);
	    }
	} else {
	    $len *= 4;
	    $off *= 4;
	}
	if ($len + $off > $size) {
	    print STDERR "error reading record at position ", 
	    tell($fh) - $binrecsize, ": ";
	    printf STDERR "%u %u %u %u %u\n", unpack("N*",$buff);
	}
    }
}

sub check_ascii {
    my $fh = shift;
    my $size = shift;
    my $buff;
    my $line = 1;
    while ($buff = <$fh>) {
	chop($buff);
	$line++;
	my ($term,$w,$c,$p,$sw,$sc,$sp) = split(/\t/,$buff);
	if ($bytes) {
	    # offsets should be on a quad-boundary
	    no integer;
	    if (int($c / 4) != ($c / 4) or
		int($p / 4) != ($p / 4) or
		int($sc / 4) != ($sc / 4) or
		int($sp / 4) != ($sp / 4)) {
		print STDERR "error reading record at position ", 
		tell($fh) - $binrecsize, ": ";
		printf STDERR "%u %u %u %u %u\n", unpack("N*",$buff);
	    }

	} else {
	    $c *= 4;
	    $p *= 4;
	    $sc *= 4;
	    $sp *= 4;
	}
	if ($c + $p > $size or $sc + $sp > $size) {
	    print STDERR "invalid record at line $line: $buff\n";
	}
    }
}
