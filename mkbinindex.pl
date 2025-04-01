#!/usr/bin/perl
#
# $Id: mkbinindex.pl,v 1.1 2005/10/25 04:08:47 ads Exp ads $
#
# This program is part of the NASA Astrophysics Data System
# abstract service loading/indexing procedure.
#
# Copyright (C): 1995 Smithsonian Astrophysical Observatory.
# You may do anything you like with this file except remove
# this copyright.  The Smithsonian Astrophysical Observatory
# makes no representations about the suitability of this
# software for any purpose.  It is provided "as is" without
# express or implied warranty.  It may not be incorporated into
# commercial products without permission of the Smithsonian
# Astrophysical Observatory.
#
#
# Creates binary index and ASCII list files for accnos with data URLs.
# The input file contains entries in the format:
#     bibcode<TAB>uri1 uri2...
# where urin is in the form: prot://host.domain[:port]/[path/[file]]
# 
# $Log: mkbinindex.pl,v $
# Revision 1.1  2005/10/25 04:08:47  ads
# Initial revision
#
# Revision 1.4  2001/12/12 19:54:03  ads
# Added --count option
#
# Revision 1.3  2000/12/08 18:26:56  ads
# Eliminated sorting of URIs (or other links)
#
# Revision 1.2  1999/11/22 15:36:33  ads
# Changed to accept stdin as input dictionary when
# `-' is specified as the file name.
#
# Revision 1.1  1996/10/30  03:11:26  ads
# Initial revision
#
#

use strict;
use integer;

my $script = $0;
$script =~ s:^.*/::;
my ($ifile,$lfile,$count_file);
my $verbose = 0;
my $binary = 0;

while (@ARGV and $ARGV[0] =~ /^--?\w/) {
    my $switch = shift(@ARGV);
    &Usage unless ($switch);
    if ($switch =~ /^--?index$/) {
	&Usage("option $switch needs a parameter")
	    if (!defined($ifile = shift(@ARGV)));
    } elsif ($switch =~ /^--?list$/) {
	&Usage("option $switch needs a parameter")
	    if (!defined($lfile = shift(@ARGV)));
    } elsif ($switch =~ /^--?binary$/) {
	$binary = 1;
    } elsif ($switch =~ /^--?verbose$/) {
	$verbose = 1;
    } elsif ($switch =~ /^--?count$/) {
	&Usage("option $switch needs a parameter")
	    if (!defined($count_file = shift(@ARGV)));
    } else {
	&Usage("unrecognized option $switch");
    }
}

Usage("when using options --index, --list, or --count, ",
      "only one input file may be specified") 
    if (@ARGV > 1 and ($ifile or $lfile));

my $dict_file;

while ($dict_file = shift(@ARGV)) {
    &Usage("no input index file specified") unless ("$dict_file");
    &Usage("file $dict_file does not exist") 
	unless (-f $dict_file or $dict_file eq '-');

    my $index_file = $ifile;
    my $list_file = $lfile;

    unless ($index_file) {
	($index_file = $dict_file) =~ s/\.\w*$//;
	$index_file .= ".index";
    }
    unless ($list_file) {
	($list_file = $dict_file) =~ s/\.\w*$//;
	$list_file .= ".list";
    }

    open(my $dfh, "< $dict_file") || 
	&Usage("cannot open input file `$dict_file': $!");
    open(my $ifh, "> $index_file") ||
	&Usage("cannot open output file `$index_file': $!");
    open(my $lfh, "> $list_file") ||
	&Usage("cannot open output file `$list_file': $!");

    my $n = 0;
    my $ptr = 0;
    my $rcount = 0;
    my $count = 0;
    local $_;

    while (<$dfh>) {
	$n++;
	chop;
	my ($bib,$uri) = split("\t",$_,2);
	next unless ($bib and $uri);
	my @uri = split(/\t+/,$uri);
	my $freq = @uri;
	$count += ($binary) ? 1 : $freq;
	$rcount++;

	my $buff = ($binary) ? pack("N*",@uri) : (join("\n",@uri) . "\n");
	my $nbytes = length($buff);
	print $lfh $buff;

	print $ifh pack("a20NNN", $bib, $freq, $nbytes, $ptr);
	$ptr += $nbytes;
    }

    warn "$script: $dict_file: processed $n entries\n" if ($verbose);

    if ($count_file) {
	open(my $cfh, "> $count_file") or 
	    &Usage("cannot open file $count_file: $!");
	print $cfh $rcount, "\t", $count, "\n";
    }
}

exit(0);

sub Usage {
    print STDERR "$script: error: @_\n" if (@_);
    print STDERR <<"EOF";
Usage: $script [options] <dict_file>
 Where dict_file is a file containing an inverted dictionary in the form
    bibcode<tab>uri1 ...
 Options: 
    --binary        assume input data is integer and write binary list file
    --count CFILE   output count file is CFILE (default: none)
    --list  LFILE   output list file is LFILE (default: <dict_file>.list)
    --index IFILE   output index file is IFILE (default: <dict_file>.index)
    --verbose       be verbose

 This script creates the following files:
    LFILE     a list of all the URIs, pointed to by the index files
              (one URI per line).  Entries have the format:
                  prot://host.domain[:port]/[path/[file]]
    IFILE     a binary inverted index of all the bibcodes.
              Records have the following format:
              bibcode\0 frequency bytes pointer
    CFILE     (optional) the number of URIs written to LFILE;
              it is the sum of the frequencies of each record in IFILE
EOF

    exit(1);
}
 
