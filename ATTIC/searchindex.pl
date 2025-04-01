#!/usr/bin/perl
#
# $Id: searchindex.pl,v 1.1 2010/05/13 14:03:38 ads Exp ads $
#
# $Log: searchindex.pl,v $
# Revision 1.1  2010/05/13 14:03:38  ads
# Initial revision
#
#

use strict;
use warnings;
use Search::Dict;
use integer;

(my $script = $0) =~ s:^.*/::;

my $printword = 1;
my $printsyn  = 1;
my $matchsubstr = 0;
my $idfile = 'bib2accno.list';
my $sortids = 0;
my $partial = 0;
my $bytes = 0;

my $usage = "Usage: $script [OPTIONS] index word [...]
OPTIONS: 
  --bytes         index file contains byte offsets
  --partial       this is a partial index (lacks score columns)
  --words-only    output only entries for words (not synonyms)
  --syns-only     output only entries for synonyms (not words)
  --match-substr  match all entries which begin with input word
  --idfile FILE   use line-to-id file FILE (default: bib2accno.list)
E.g. $script --words-only author accomazzi
";

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--words-only') {
	$printsyn = 0;
    } elsif ($opt eq '--syns-only' or $opt eq '--synonyms-only') {
	$printword = 0;
    } elsif ($opt eq '--match-substr') {
	$matchsubstr = 1;
    } elsif ($opt eq '--partial') {
	$partial = 1;
    } elsif ($opt eq '--bytes') {
	$bytes = 1;
    } elsif ($opt eq '--idfile') {
	$idfile = shift(@ARGV) || '';
    } elsif ($opt eq '--sort-ids') {
	$sortids = 1;
    } elsif ($opt eq '--help') {
	die $usage;
    } else {
	die $usage;
    }
}

die "$script: idfile $idfile not found!" unless (-f $idfile);
my $idmap = init_idfile($idfile) or
    die "$script: error opening id file $idfile: $!";

my $index = shift(@ARGV) or die $usage;
$index .= ".index" unless ($index =~ /\.index$/);
die "$script: index file $index not found" unless (-f $index);
open(my $ifh, $index) or die "$script: cannot open file $index: $!";

my $list = $index;
$list =~ s/\.index$//;
$list .= ".list";
die "$script: list file $list not found" unless (-f $list);
open(my $lfh, $list) or die "$script: cannot open file $list: $!";

die $usage unless (@ARGV);

while (my $word = shift(@ARGV)) {
    # this is a word to search for
    $word = uc($word);
    warn "$script: searching for \"$word\" in file \"$index\":\n";
    look($ifh,$word,0,0);
    my $getnext = 1;

    while ($getnext) {
	$getnext = 0;
	my $e = <$ifh>; chop($e);
	my ($term,@rest) = split(/\t/,$e);
	if ($matchsubstr and $word eq substr($term,0,length($word))) {
	    $getnext = 1;
	} elsif ($word eq $term) {
	    
	} else {
	    warn "$script: word \"$word\" not found in index\n";
	    next;
	}
	my ($w,$c,$p,$sw,$sc,$sp);
	if ($partial) {
	    ($c,$p,$sc,$sp) = @rest;
	    $w = $sw = 'N/A';
	} else {
	    ($w,$c,$p,$sw,$sc,$sp) = @rest;
	}

	if (not $bytes) {
	    $c *= 4;
	    $p *= 4;
	    $sc *= 4;
	    $sp *= 4;
	}

	my $buff;
	if ($printword) {
	    if ($c) {
		print "$term: (words):\tweight=$w\tcount=", $c/4, "\tptr=$p\n";
		seek($lfh,$p,0);
		read($lfh,$buff,$c) or
		    die "$script: cannot read $c bytes from file \"$list\": $!";
		print "#\tline\tid\n"; 
		my @ids = unpack("N*",$buff);
		@ids = sort { $a <=> $b } @ids if ($sortids);
		my @docs = id2doc($idmap,@ids);
		while (@ids) {
		    print "\t", shift(@ids), "\t", shift(@docs);
		}
	    } else {
		print "$term: (words):\tNONE\n";
	    }
	}
	
	if ($printsyn) {
	    if ($sc) {
		print "$term (syns):\tweight=$sw\tcount=", $sc/4, "\tptr=$sp\n";
		seek($lfh,$sp,0);
		read($lfh,$buff,$sc) or
		    die "$script: cannot read $sc bytes from file \"$list\": $!";
		print "#\tline\tid\n"; 
		my @ids = unpack("N*",$buff);
		@ids = sort { $a <=> $b } @ids if ($sortids);
		my @docs = id2doc($idmap,@ids);
		while (@ids) {
		    print "\t", shift(@ids), "\t", shift(@docs);
		}
	    } else {
		print "$term: (syns):\tNONE\n";
	    }
	}
    }
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
