#!/usr/bin/perl
#
# Joins consecutive text lines which have the same first column (tab separated);
# each line is expected to have a "phrase" in it after teh identifier,
# consisting of a list of space-separated words.  These are parsed and
# concatenated by separating each word with a tab and each phrase with two
# tabs (so that words from different phrases do not make it into the 
# word-pair index used for phrase searches).
# Example of input file:
#    accno1<tab>word11 word12
#    accno1<tab>word13 word14...
#    accno2<tab>word21 word22...
# Output:
#    accno1<tab>word11<tab>word12<tab><tab>word13<tab>word14<tab>...
#    accno2<tab>word21<tab>word22<tab>...
#
use strict;
use warnings;

my $script = $0; $script =~ s:^.*/::;

my $ot = "";
while (<>) {
    chop;
    my ($t,@w) = split;
    if ($t ne $ot) {
	# start new line
	print "\n" if ($ot ne "");
	print $t, "\t";
    } else {
	print "\t\t";
    }
    print join("\t",@w);
    $ot = $t;
}
# print last newline if any input was read
print "\n" if ($ot ne "");
