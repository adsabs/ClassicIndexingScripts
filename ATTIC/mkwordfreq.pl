#!/usr/bin/perl
#
# $Id: mkwordfreq.pl,v 1.1 2011/10/07 16:15:19 ads Exp ads $
#
# mkwordfreq.pl --bytes --ntot 1403204 text.syn \
#               ../../load/current/text.index > text.freq
#
# $Log: mkwordfreq.pl,v $
# Revision 1.1  2011/10/07 16:15:19  ads
# Initial revision
#
#

use strict;
use warnings;
use integer;
use ADS::Abstracts::Index;

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script --ntot NTOT [OPTIONS] synonym_file index_file > word.freq
Options:
  --bytes         offsets are counted in bytes, not longs
  --debug         print debugging information
  --strip-parens  strip words containing parentheses: ()
  --strip-dashes  strip words with m-dashes or starting/ending with dashes
  --strip-numbers strip words which consist of numbers or number ranges
  --strip-all     strip all non-alphanumeric words
  --strip         short hand notation for:
                  --strip-parens --strip-dashes --strip-numbers
  --thresh N      ignore words with a frequency lower than N
EOF
    ;

my $debug = 0;
my $ntot = 0;
my $factor = 1;
my $strip_all = 0;
my $strip_parens = 0;
my $strip_dashes = 0;
my $strip_numbers = 0;
my $threshold = 0;

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--strip-all') {
	$strip_all = 1;
    } elsif ($opt eq '--strip-parens') {
	$strip_parens = 1;
    } elsif ($opt eq '--strip-dashes') {
	$strip_dashes = 1;
    } elsif ($opt eq '--strip-numbers') {
	$strip_numbers = 1;
    } elsif ($opt eq '--strip') {
	$strip_parens = 1;
	$strip_dashes = 1;
	$strip_numbers = 1;
    } elsif ($opt eq '--bytes') {
        $factor = length(pack("N", 1));
    } elsif ($opt eq '--ntot') {
        $ntot = shift(@ARGV);
    } elsif ($opt eq '--thresh') {
        $threshold = shift(@ARGV);
    } elsif ($opt eq '--help') {
        die $usage;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}
die "$script: must supply total number of document via --ntot flag"
    unless ($ntot);
die $usage unless(@ARGV);
my $synfile = shift(@ARGV);
die $usage unless(@ARGV);
my $file = shift(@ARGV);

my ($nsyns,undef,$syngroup) = ADS::Abstracts::Index::readsyns($synfile);
my %index = ADS::Abstracts::Index::readindex($file);

my %synonym;
for (my $group = 1; $group <= $nsyns; $group++) {
    my @words = @{ $syngroup->[$group] };
    my $topsyn = '';
    my $topfreq = 0;
    foreach my $word (@words) {
	next unless ($index{$word});
	if ($index{$word}->[1] > $topfreq) {
	    $topsyn = $word;
	    $topfreq = $index{$word}->[1];
	}
    }
    foreach my $word (@words) {
	next unless ($index{$word});
	$synonym{$word} = $topsyn;
    }
}

my ($word,$rest);
while (($word,$rest) = each(%index)) {
    if ($strip_all and $word =~ /\W/) {
	next;
    } elsif ($strip_parens and $word =~ /[\(\)]/) {
	next;
    } elsif ($strip_dashes and $word =~ /\-\-/ or $word =~ /^\-|\-$/) {
	next;
    } elsif ($strip_numbers and $word =~ /^[0-9\.\-\+]+$/ or $word =~ /^[\d+]x[\d+]$/) {
	next;
    }
    # synonym frequency
    my $freq = $rest->[4] / $factor;
    my $syn = $synonym{$word} || $word;
    if ($freq >= $threshold) { 
	no integer; 
	print join("\t",$word,$syn,$freq / $ntot), "\n";
    }
}

