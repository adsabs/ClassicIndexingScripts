#!/usr/bin/perl
#
#

use strict;

my $fmt;
my $factor = 4;

while (<>) {
    chop;
    my ($word,$score,$bytes,$offs,$sscore,$sbytes,$soffs,@rest) = split(/\t/);
    # this is the header line
    unless (defined($soffs)) {
	print $_, "\n";
	next;
    }
    $bytes  /= $factor;
    $sbytes /= $factor;
    $offs   /= $factor;
    $soffs  /= $factor;
    $fmt ||= "%s" . "\t%u" x (6 + scalar(@rest)) . "\n";
    printf ($fmt,$word,$score,$bytes,$offs,$sscore,$sbytes,$soffs,@rest) or
	die "$0: error writing entry for \"$word\" to index file";
}

