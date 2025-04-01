#!/usr/bin/env perl
#
# $Id$
#
# removes synonym groups that contain one or more words from the syonym file
#
# $Log$
#

use strict;
use warnings;
use ADS::Abstracts::Index;

(my $script = $0) =~ s:^.*/::g;

my $usage = "Usage: $script [--debug] syn_file < remove_list\n";
my $debug = 0;

while (@ARGV and $ARGV[0] =~ /^-/) {
    my $s = shift(@ARGV);
    if ($s eq '--debug') {
        $debug++;
    } elsif ($s eq '--help') {
        die $usage;
    } else {
        die "Unknown option \"$s\"\n", $usage;
    }
}

my $synfile = shift(@ARGV) or die $usage;
die $usage if (@ARGV);
my ($nsyns,$group,$syns) = ADS::Abstracts::Index::readsyns($synfile)
    or die "$script: cannot read synonym file $synfile\n";
warn "$script: read $nsyns synonym groups from file $synfile\n";

while (<>) {
    my ($killword) = split;
    $killword = uc($killword);
    my $groupno = $group->{$killword};
    next unless ($groupno);
    my @s = @{$syns->[$groupno]};
    warn "$script: found $killword in group $groupno: ", join(" ", @s), "\n";
    foreach my $s (@s) {
	$group->{$s} = 0;
    }
}

my $n = ADS::Abstracts::Index::writesyns(\*STDOUT,$group);
warn "$script: written $n synonyms to STDOUT\n";
