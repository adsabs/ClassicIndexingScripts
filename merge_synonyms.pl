#!/usr/bin/env perl
#
# $Id$
#
# Merges synonym files
#
# $Log$
#

use strict;
use warnings;
use ADS::Abstracts::Index;

(my $script = $0) =~ s:^.*/::g;
my %newsyns = ();
my @newgroup;
my $newgid = 1;

my $usage = "Usage: $script [--debug] syn_file [...]\n";
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


while (@ARGV) {
    my $synfile = shift(@ARGV);
    my ($nsyns,$group,$syns) = ADS::Abstracts::Index::readsyns($synfile, keepchars => 'A-Za-z,')
	or die "$script: cannot read synonym file $synfile\n";
    warn "$script: read $nsyns synonym groups from file $synfile\n";

    for (my $i = 1; $i <= $nsyns; $i++) {
	next unless ($syns->[$i]);
	my @s = @{$syns->[$i]};
	if ($#s == 0) {
	    # there is just one synonym here; no need for a group
	    warn "$script: $synfile: ignoring single synonym \"$s[0]\"\n";
	    next;
	}

	my $groupno = 0;
	my $synfound = '';
	my @syngroup = @s;
	foreach my $s (@s) {
	    if ($newsyns{$s}) {
		warn "$script: $synfile: merging syn \"$s\" with existing ",
		"group\n";
		if ($groupno and $groupno ne $newsyns{$s} and 
		    $newgroup[$newsyns{s}]) {
		    warn "$script: $synfile: warning: merging synonym groups ",
		    "for \"$s\" and \"$synfound\"\n";
		    my @g = @{$newgroup[$newsyns{$s}]};
		    push(@syngroup,@g);
		    $newgroup[$newsyns{$s}] = [];
		    foreach my $g (@g) {
			$newsyns{$g} = $groupno;
		    }
		} else {
		    $groupno = $newsyns{$s};
		}
		$synfound = $s;
	    }
	}
	
	if (not $groupno) {
	    warn "$script: $synfile: creating new groupid for group ",
	    "containing \"$syngroup[0]\"\n" if ($debug);
	    $groupno = $newgid++;
	}

	my %g = map { ($_,1) } @syngroup;
	$newgroup[$groupno] = [ sort keys %g ];
	foreach my $s (@syngroup) {
	    $newsyns{$s} = $groupno;
	}
	
    }	
}

my $n = ADS::Abstracts::Index::writesyns(\*STDOUT,\%newsyns);
warn "$script: written $n synonyms to STDOUT\n";
