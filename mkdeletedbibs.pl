#!/usr/bin/env perl
#
# $Id$
#
# Creates bibcodes deleted list by filtering out
# entries not required according to local bib2accno
#
# $Log$
#

use strict;
use warnings;
use integer;
use Search::Dict;

(my $script = $0) =~ s:^.*/::;

my $usage = <<EOF;
Usage: $script [OPTIONS] bib2accno.list < bibcodes.deleted > bibcodes.list.del
$script outputs those records from bibcodes.deleted which 
correspond to entries in the input bib2accno.list, filtering out
any entries which may be only relevant to other databases.
EOF
    ;

my $debug = 0;
my $alternates = (@ARGV and $ARGV[0] eq '--alternates') ? shift(@ARGV) : 0;
my $b2a = shift(@ARGV) or die $usage;

open(my $fh, $b2a) or die "$script: cannot open bib2accno file $b2a: $!";

my %delbibs;
while (<STDIN>) {
    my ($del,$repl) = split;
    next unless ($del and $del =~ /\A\d{4}\S{15}\Z/);
    if ($alternates) {
	next unless ($repl =~ /\A\d{4}\S{15}\Z/);
    }
    if ($del eq $repl) {
	warn "$script: loop in deleted bibcode lookup for $del\n";
	next;
    }
    $delbibs{$del} = $repl || '';
}

# we do a second pass on the bibcodes in order to replace
# each bibcode with its final replacement (since a deleted
# bibcode can appear in both columns)
my @delbibs = keys(%delbibs);
while (@delbibs) {
    my $del = shift(@delbibs);
    my $repl = $delbibs{$del};
    my %tmp;
    $tmp{$del}++;
    while ($repl) {
	if ($repl eq $del) {
	    warn "$script: loop in deleted bibcode lookup for $del\n";
	    delete($delbibs{$del});
	} elsif ($delbibs{$repl}) {
	    warn "$script: fixed lookup for $repl: $delbibs{$repl}\n";
	    $tmp{$repl}++;
	}
	$repl = $delbibs{$repl};
	if ($repl) {
	    if ($tmp{$repl}) {
		warn "$script: loop in delete bibcode lookup for $repl\n";
		delete($delbibs{$repl});
		$repl = undef;
	    } else {
		$delbibs{$del} = $repl;
	    }
	}
    }
}

@delbibs = keys(%delbibs);
while (@delbibs) {
    my $del = shift(@delbibs);
    my $repl = $delbibs{$del};
    if (not $repl) {
	print $del, "\n";
	next;
    }
    look($fh,$repl,0,1);
    my $r = <$fh>;
    if ($r and substr($r,0,length($repl)) eq $repl) {
	print $del, "\t", $repl, "\n";
    } elsif ($debug) {
	warn "discarding entry $_";
    }
}

