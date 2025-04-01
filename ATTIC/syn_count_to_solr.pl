#!/usr/bin/perl
#
# Reads synonym file with frequency count, and prints out
# an explicit synonym mapping to be used in solr.  
# All words in a group are mapped to the one with the highest frequency
#


use strict;
my $usage = "$0 < syn_file_count > syn_file_solr\n";

# read one paragraph at a time
$/ = "";
my @groups = ();
while (<>) {
    s/\A\s*|\s*\Z//g;
    my %syns = map { 
	s/\s*\#.*//g;
	my ($w,$c) = split;
	($w and $c) ? (lc($w),$c) : ();
    } split(/\n/);

    my @syns = sort { $syns{$b} <=> $syns{$a} } keys %syns;

    # AA 9/20/13 - as per Roman's request, keep canonical
    # synonym term in LHS of synonym map as well
    # my $top = shift(@syns);
    my $top = $syns[0];
    next unless ($#syns > 0);

    print join(", ", @syns), " => ", $top, "\n";
}
