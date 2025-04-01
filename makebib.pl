#!/usr/bin/perl
#
# $Id: makebib.pl,v 1.5 2011/09/30 21:18:14 ads Exp ads $
#
# This program is part of the NASA Astrophysics Data System
# abstract service loading/indexing procedure.
#
# Copyright (C): 1994-2002 Smithsonian Astrophysical Observatory.
# You may do anything you like with this file except remove
# this copyright.  The Smithsonian Astrophysical Observatory
# makes no representations about the suitability of this
# software for any purpose.  It is provided "as is" without
# express or implied warranty.  It may not be incorporated into
# commercial products without permission of the Smithsonian
# Astrophysical Observatory.
#
#
# Creates bib2accno.list and bibcodes.list.alt by reading entries
# in the master list file.
#
# AA 12/11/2002
# 
# $Log: makebib.pl,v $
# Revision 1.5  2011/09/30 21:18:14  ads
# Implemented creation of master.bib
#
# Revision 1.3  2004/03/30 16:49:41  ads
# Be more verbose when conflicts arise with multiple bibcodes
# matching the same merged accnos.
#
# Revision 1.2  2003/11/08 03:17:07  ads
# Removed hack forcing exit via POSIX call to deal with
# buggy libc.
#
# Revision 1.1  2002/12/12 02:19:15  ads
# Initial revision
#
#

use strict;
use integer;

(my $script = $0) =~ s:^.*/::;
my $start_entdate = 0;
my $start_pubdate = 0;
my $index_entdate = 0;
my $index_pubdate = 0;

my $bib2accno = "bib2accno.list";
my $altbib = "bibcodes.list.alt";
my $bibmaster = "master.bib";
my $output = "-";
my $topdir = ".";
my $verbose = 0;

while (@ARGV and $ARGV[0] =~ /^--\w/) {
    my $switch = shift(@ARGV);
    if ($switch eq "--output") {
	Usage("no arguments given to option $switch") 
	    unless (defined($output = shift(@ARGV)));
    } elsif ($switch eq "--topdir") {
	Usage("no arguments given to option $switch") 
	    unless (defined($topdir = shift(@ARGV)));
    } elsif ($switch eq "--bib2accno") {
	Usage("no arguments given to option $switch") 
	    unless (defined($bib2accno = shift(@ARGV)));
    } elsif ($switch eq "--altbib") {
	Usage("no arguments given to option $switch") 
	    unless (defined($altbib = shift(@ARGV)));
    } elsif ($switch eq "--bibmaster") {
	Usage("no arguments given to option $switch") 
	    unless (defined($bibmaster = shift(@ARGV)));
    } elsif ($switch eq "--since-entdate") {
	Usage("no arguments given to option $switch") 
	    unless (defined($start_entdate = shift(@ARGV)));
    } elsif ($switch eq "--since-pubdate") {
	Usage("no arguments given to option $switch") 
	    unless (defined($start_pubdate = shift(@ARGV)));
    } elsif ($switch eq "--index-entdate") {
	Usage("no arguments given to option $switch") 
	    unless (defined($index_entdate = shift(@ARGV)));
    } elsif ($switch eq "--index-pubdate") {
	Usage("no arguments given to option $switch") 
	    unless (defined($index_pubdate = shift(@ARGV)));
    } elsif ($switch eq "--verbose") {
	$verbose = 1;
    } elsif ($switch eq '--help') {
	Usage();
    } else {
	Usage("unrecognized option $switch");
    }
}

my $master = shift(@ARGV);
Usage("no input file specified") unless ($master);
Usage("only one input file allowed") if (@ARGV);

my $tmpdir = $ENV{ADS_TMP} || $ENV{TMPDIR} || '.';
warn "$script: processing started at ", scalar localtime(time), "\n";

#if (system("sort +1 -3 -T $tmpdir -o ./master.list.sorted $master")) {
if (system("sort -k +2,4 -T $tmpdir -o ./master.list.sorted $master")) {
    die "$script: cannot sort master list";
} else {
    warn "$script: created ./master.list.sorted from $master\n";
    $master = "./master.list.sorted";
}
#open(my $ifh, "sort +1 -3 -T $tmpdir $master |") or
#    die "$script: cannot open pipe \"sort +1 -3 -T $tmpdir $master\": $!";

open(my $ifh, $master) or
    die "$script: cannot open input file $master";
open(my $ofh, "> $output") or
    die "$script: cannot open output file $output: $!";
open(my $bfh, "> $bib2accno") or 
    die "$script: cannot open output file $bib2accno: $!";
open(my $afh, "> $altbib") or
    die "$script: cannot open output file $altbib: $!";
open(my $mfh, "> $bibmaster") or
    die "$script: cannot open output file $bibmaster: $!";

my $b2a = {};
my $alt = {};
my $ucb = {};
my $bm  = {};
my $or = { maccno => undef };
my @r = ();

while (not eof($ifh)) {
    
    my $r = get_record($ifh) or next;

    if ($r->{maccno} eq $or->{maccno}) {
	# while we find records with the same merged accno, accumulate them

    } elsif (@r) {
	my $m = add_records($b2a,$alt,$ucb,$bm,@r);
	print_record($ofh, $m) if ($m);
	@r = ();
    }
    
    push(@r, $or = $r);
}
my $m = add_records($b2a,$alt,$ucb,@r);
print_record($ofh, $m) if ($m);

# now print out bib2accno file
my $n = print_b2a($bfh, $b2a);
warn "$script: printed ", $n + 0, " entries to file $bib2accno\n";

$n = print_alt($afh, $alt);
warn "$script: printed ", $n + 0, " entries to file $altbib\n";

$n = print_bm($mfh, $bm);
warn "$script: printed ", $n + 0, " entries to file $bibmaster\n";


sub print_bm {
    my $fh = shift;
    my $bm = shift;
    my $n = 0;

    my @k = keys %$bm;
    while (@k) {
	my $k = shift(@k);
	my $recs = $bm->{$k};
	foreach my $r (@{$recs}) {
	    $n += print $fh join("\t", $k, @{$r}), "\n";
	}
    }
    return $n;
}

sub print_b2a {
    my $fh = shift;
    my $b2a = shift;
    my $n = 0;
    
    my @k = keys %$b2a;
    while (@k) {
	my $k = shift(@k);
	my $r = $b2a->{$k};
	$n += print $fh join("\t",$k,$r->{accno},$r->{pubdate},$r->{entdate}),
	"\n";
    }
    return $n;
}

sub print_alt {
    my $fh = shift;
    my $alt = shift;
    my $n = 0;
    
    my @k = keys %$alt;
    while (@k) {
	my $k = shift(@k);
	$n += print $fh join("\t",$k,$alt->{$k}), "\n";
    }
    return $n;
}

# 
# prints a the entry corresponding to a record to $fh
#
sub print_record {
    my $fh = shift;
    my $r = shift or return 0;

    if ($r->{pubdate} < $index_pubdate or 
	$r->{entdate} < $index_entdate) {
	print $fh $r->{accno}, "\n";
    } else {
	print $fh join("\t",$r->{accno},$r->{file},$r->{timestamp}), "\n";
    }
}

#
# the input parameters to the subroutine are:
#    $b2a => bib2accno hashref
#    $alt => alternate bibcode hashref
#    $ucb => upper case bibcode hashref
#    $bm  => bibmaster hashref
#    @r   => array of hash pointers
#
sub add_records {
    my $b2a = shift;
    my $alt = shift;
    my $ucb = shift;
    my $bm  = shift;
    return undef unless @_;

    my $merged;
    my @rest = ();
    while (@_) {
	my $r = shift;
	if ($r->{maccno} eq $r->{oaccno}) {
	    if ($merged) {
		warn "$script: multiple merged entries exist for accno ", 
		$r->{oaccno},": ",$merged->{bibcode}," ",$r->{bibcode},"\n";
	    } else {
		$merged = $r;
	    }
	} else {
	    push(@rest,$r);
	}
    }

    unless ($merged) {
	my $r = shift(@rest);
	warn "$script: no matching original accno found for ", 
	join("\t", $r->{bibcode}, $r->{maccno}, $r->{oaccno}), "\n";
	return undef;
    }
    my $bibcode = $merged->{bibcode};
    my $accno = $merged->{maccno};

    # skip record if it's not in the date range needed
    if ($merged->{pubdate} < $start_pubdate or 
	$merged->{entdate} < $start_entdate) {
	return undef;
    }
    
    my ($absfile,$timestamp) = abs_file($accno) or return undef;
    $bm->{$bibcode} = [ [ $absfile, $timestamp, 'primary' ] ];

    # create main entry in bib2accno
    if ($b2a->{$bibcode}) {
	warn "$script: Warning: bibcode \"$bibcode\" already assigned",
	" to accno \"", $b2a->{$bibcode}->{accno}, 
	"\", ignoring accno \"$accno\" (skipped)\n";
	return undef;

    } elsif ($ucb->{uc($bibcode)}) {
	# now try to see if this bibcode has been seen before
	# in a case-insensitive way
	warn "$script: Warning: bibcode \"$bibcode\" matches ",
	"case-insensitively with bibcode \"", $ucb->{uc($bibcode)}, 
	"\" (skipped)\n";
	return undef;
    }

    # if we got so far, we're in good shape
    $b2a->{$bibcode} = { 
	accno   => $accno,
	pubdate => $merged->{pubdate},
	entdate => $merged->{entdate},
    };
    $ucb->{uc($bibcode)} = $bibcode;

    # now build alternate bibcodes, if any
    while (@rest) {
	my $r = shift(@rest);
	my @a = abs_file($r->{oaccno});
	if ($r->{bibcode} ne $bibcode) {
	    $alt->{$r->{bibcode}} = $bibcode;
	    push(@a, $r->{bibcode}) if (@a);
	}
	push(@{$bm->{$bibcode}}, [ @a ]) if (@a);
    }

    return {
	accno     => $accno,
	file      => $absfile,
	timestamp => $timestamp,
    };
}

sub abs_file {
    my $accno = shift;

    # build filename and check existance
    unless ($accno =~ /^(\w\d\d)/) {
	warn "$script: bogus accno \"$accno\" at line (skipped)\n";
	return ();
    }
    my $absfile = "$topdir/$1/$accno.abs";
    unless (-f $absfile) {
	warn "$script: Warning: text file ",
	"\"$absfile\" not found (skipped)\n";
	return ();
    }
    my $timestamp = (stat($absfile))[9];
    unless ($timestamp) {
	warn "$script: Warning: cannot get modification time for  accno ",
	"\"$accno\" (skipped)\n";
	return ();
    }	

    return($absfile,$timestamp);
}


sub get_record {
    my $fh = shift;
    my $entry = <$fh>;

    unless (defined($entry)) {
	warn "$script: Warning: read error at line $.\n";
	return undef;
    }
    chop($entry);
    my ($bib,$acc,$oacc,$pd,$ed) = split(/\s+/,$entry);

    # sanity checks on all entries but last
    if ($entry =~ /^\s*$/) {
	warn "$script: Warning: blank record found at line $. (skipped)\n";
	return undef;
    } elsif (length($bib) != 19 or $bib !~ /[\w\.\:]$/) {
	warn "$script: Warning: bad bibcode \"$bib\" ",
	"for record \"$entry\" at line $. (skipped)\n";
	return undef;
    } elsif ($acc !~ /^[A-Z]\d\d\-\d\d\d\d\d$/) {
	warn "$script: Warning: bad merged accno \"$acc\" ",
	"for record \"$entry\" at line $. (skipped)\n";
	return undef;
    } elsif ($oacc !~ /^[A-Z]\d\d\-\d\d\d\d\d$/) {
	warn "$script: Warning: bad orig accno \"$oacc\" ",
	"for record \"$entry\" at line $. (skipped)\n";
	return undef;
    } elsif ($pd !~ /^\d\d\d\d+$/) {
	warn "$script: Warning: bad pubdate \"$pd\" ",
	"for record \"$entry\" at line $. (skipped)\n";
	return undef;
    } elsif ($ed !~ /^\d\d\d\d\d\d+$/) {
	warn "$script: Warning: bad entry date \"$ed\" ",
	"for record \"$entry\" at line $. (skipped)\n";
	return undef;
    }
    if ($bib =~ /^(\d\d)(\d\d)/) {
	my $c = "$1";  my $y = "$2";
	$pd =~ /(\d\d)(\d\d)$/;
	my $py = "$1"; my $pm = "$2";
	# here we do a special kludge to handle cases where the 
	# publication year and the bibcode year don't match,
	# so we can figure out the correct century for the pubyear
	if ($y ne $py) {
	    if ($y - $py > 10) {
		# e.g.: bibyear = 1998, pubyear = 2000 gives
		# $y = 98; $py = 00;
		$c++; 
	    } elsif ($py - $y > 10) {
		# e.g.: bibyear = 2000, pubyear = 1999 gives
		# $y = 00; $py = 99;
		$c--;
	    }
	    warn "$script: Warning: pubyear ($py) does not match ",
	    "bibcode \"$bib\", at line $., setting pubyear to \"$c$py\"\n";
	}
	$pd = "$c$py$pm";
    } else {
	warn "$script: Warning: bibcode \"$bib\" does not ",
	"start with a year at line $. (skipped)\n";
	return undef;
    }
    if (length("$ed") == 6) {
	if ($ed > 900000) {
	    $ed = "19$ed";
	} else {
	    $ed = "20$ed";
	}
    } elsif (length("$ed") != 8) {
	warn "$script: Warning: bad entry date \"$ed\" ",
	"for record \"$entry\" (skipped)\n";
	return undef;
    }	    

    return {
	bibcode => $bib,
	maccno  => $acc,
	oaccno  => $oacc,
	pubdate => $pd,
	entdate => $ed,
	};
}


sub Usage {
    warn "$script: ", @_, "\n" if @_;
    warn "Usage: $script [OPTIONS] master_list
 This programs reads the master_list file (standard input if - is specified), 
 and writes to STDOUT the bibcode-accnofile entries in the format:
    accno<tab>filepath
 Example:
    A86-18872  /proj/adsfore/abstracts/ast/text/A86/A86-18872.abs
 The program also creates two ancillary files, $bib2accno and 
 $altbib, which are used by the search engine

 Options:
    --bib2accno FILE   output bib2accno file is FILE (default: $bib2accno)

    --altbib FILE      output altbib file is FILE (default: $altbib)

    --bibmaster FILE   output master bib file to FILE (default: $bibmaster)

    --output FILE      write the output to file FILE rather than STDOUT

    --topdir DIR       abstract files are under directory DIR

    --verbose          turn verbose mode on

    --since-entdate YYYYMMDD   
                       only entries with an entry date more recent than
                       YYYYMMDD are written to the output file.
                       Default is 0, ie. output all entries.

    --since-pubdate YYYYMM
                       only entries with an publication date more recent
                       than YYYYMMDD are written to the output file.
                       Default is 0, ie. output all entries.

    --index-entdate YYYYMMDD   
                       only filenames associated with a record with entry 
                       date more recent than YYYYMMDD are written to the 
                       output file and therefore indexed.
                       Default is 0, ie. output all entries.

    --index-pubdate YYYYMM
                       only filenames associated with a record with 
                       publication date more recent than YYYYMMDD are 
                       written to the output file and therefore indexed.
                       Default is 0, ie. output all entries.
";

    exit(1);
}
