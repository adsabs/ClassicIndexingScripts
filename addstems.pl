#!/usr/bin/perl
#
# $Id: addstems.pl,v 1.1 2003/11/08 03:19:14 ads Exp ads $
#
# This program is part of the NASA Astrophysics Data System
# abstract service loading/indexing procedure.
#
# Copyright (C): 1994, 1995 Smithsonian Astrophysical Observatory.
# You may do anything you like with this file except remove
# this copyright.  The Smithsonian Astrophysical Observatory
# makes no representations about the suitability of this
# software for any purpose.  It is provided "as is" without
# express or implied warranty.  It may not be incorporated into
# commercial products without permission of the Smithsonian
# Astrophysical Observatory.
#
#
# Creates stems from entries in index file
# 
# $Log: addstems.pl,v $
# Revision 1.1  2003/11/08 03:19:14  ads
# Initial revision
#
# Revision 1.1  1996/03/30  19:00:48  ads
# Initial revision
#
#

use strict;
use integer;
use IPC::Open2;

(my $script = $0) =~ s:^.*/::;
my $usage = <<EOF;
Usage: $script [--configdir DIR] [--debug] index_file [...]
EOF
    ;
my $debug = 0;
my $configdir = ".";

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--help') {
        die $usage;
    } elsif ($opt eq '--configdir') {
        $configdir = shift(@ARGV);
    } elsif ($opt eq '--debug') {
        $debug = 1;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}

die $usage unless(@ARGV);

# create pipe for stemming
my ($rstemmer,$wstemmer);
open2($rstemmer, $wstemmer, "text_stemmer $configdir") or
    die "$script: open2 failed: $!\n";
warn "$@\n" if ($@);

warn "$script: execution starting at ", scalar localtime(time), "\n";

while (@ARGV) {
    my $indexfile = shift;
    open(my $ifh, $indexfile) or 
        die "$script: error reading index file $indexfile: $!";
    my $newindex = $indexfile . ".stems";
    open(my $ofh, "> $newindex") or 
        die "$script: error opening output file $newindex: $!";
    
    warn "$script: stem creation for $indexfile started at ", 
    scalar localtime(time), "\n";
    my $killfile = $indexfile;
    $killfile =~ s/\.index$/.kill/; $killfile =~ s:^.*/::;
    $killfile = $configdir . '/' . $killfile;
    my $iskill = {};
    if (-f $killfile) {
	$iskill = readkillwords($killfile) or
	    die "$script: cannot read kill word filr $killfile: $!";
	warn "$script: read ", scalar keys %$iskill, " kill words from file ",
	$killfile, "\n";
    } else {
	warn "$script: warning: no kill word file found for index $indexfile\n";
    }
    my %records = readindex($indexfile) or 
        die "$script: could not read index file $indexfile: $!";

    my @words = sort keys %records;
    my $w;
    my %stems;
    while (defined($w = shift(@words))) {
	next unless ($w =~ /^[A-Z]/) ;
	my $s = &Stemmer($rstemmer,$wstemmer,$w);
	next if ($s eq '' or $iskill->{$s} or defined($records{$s}));
	# if the record corresponding to the word currently being stemmed
	# has a higher frequency than the current stem entry, then set it
	# to be the one corresponding to the stem
	warn "$script: adding stem \"$s\"\n" if ($debug);
	if ($stems{$s}) {
	    $stems{$s} = $records{$w} if ($records{$w}->[2] > $stems{$s}->[2]);
	} else {
	    $stems{$s} = $records{$w};
	}
    }

    unless (%stems) {
	warn "$script: no new stems generated from $indexfile\n";
	next;
    }

    my @stems = sort keys %stems;
    warn "$script: adding ", scalar @stems, " stems to $indexfile\n";
    while (@stems) {
	my $s = shift(@stems);
	my @s = @{$stems{$s}};
	print $ofh join("\t", $s, 0, 0, @s[2 .. $#s]), "\n";
    }
    close($ofh);
    
    # append stems to index file
    die "$script: cannot append stem entries from ",
    "$newindex to $indexfile: $!"
	if (system("sort -T . -f -o $indexfile $indexfile $newindex"));
    warn "$script: stem creation for $indexfile ended at ", 
    scalar localtime(time), "\n";
}

warn "$script: stem creation ended at ", scalar localtime(time), "\n";

sub Stemmer {
    my $reader = shift;
    my $writer = shift;
    my $w = shift;
    return '' unless($w);

#    warn "$script: writing word \"$w\" to stemmer\n" if ($debug);
    print $writer "$w\n" or
	die "$script: error writing to stemmer";
    my $s = <$reader>;
    chop($s);
#    warn "$script: read word \"$s\" from stemmer\n" if ($debug);
    return '' unless ($s);
    return '' if ($s eq $w);
    warn "$script: $w -> $s\n" if ($debug);
    return $s;
}


sub readkillwords {
    my $file = shift;
    open(my $fh, $file) or return undef;
    my %hash = map { s/\s+//g; (uc($_),1) } <$fh>;
    return \%hash;
}

sub readindex {
    my $file = shift;
    open(my $fh, $file) or return ();
    my %records = ();

    while (my $r = <$fh>) {
        chop($r);
        my ($word,@rest) = split(/\t+/,$r);
        $records{$word} = [ @rest ];
    }
    return %records;
}

