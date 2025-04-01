#!/usr/bin/env perl
#
# Creates full author synonyms from the file containing just
# "LAST, F" entries
#

use strict;
use warnings;
use ADS::Abstracts::Index;
use Search::Dict;

my $script = $0; $script =~ s:^.*/::;
my $usage = "Usage: $script [OPTIONS] input_syn_file index_file [...]
OPTIONS:
  --debug          print debugging information to STDERR
  --exclude FILE   exclude synonyms in FILE from the generated list
  --keep-single    keep single synonyms in output

$script reads a list of (possibly partial) author synonyms, compares
the names in them against one or more full author index, and outputs
the corresponding list of full author synonyms
";
my $debug = 0;
my $xsynfile;
my $nosingle = 1;

while (@ARGV and $ARGV[0] =~ /^-/) {
    my $s = shift(@ARGV);
    if ($s eq '--debug') {
	$debug++;
    } elsif ($s eq '--exclude') {
	$xsynfile = shift(@ARGV);
    } elsif ($s eq '--keep-single') {
	$nosingle = 0;
    } elsif ($s eq '--help') {
	die $usage;
    } else { 
	die "Unknown option \"$s\"\n", $usage;
    }
}

my $synfile = shift(@ARGV) or die $usage;
my ($nsyns,$group,$syns) = ADS::Abstracts::Index::readsyns($synfile, keepchars => 'A-Za-z,')
    or die "$script: cannot read synonym file $synfile\n";
warn "$script: read ", $nsyns, " synonym groups from file $synfile\n";


my @ifh;
die $usage unless (@ARGV);
while (@ARGV) {
    my $index = shift(@ARGV) or die $usage;
    open(my $ifh, $index) or die "$script: cannot open index $index: $!";
    push(@ifh,$ifh);
}

if ($xsynfile) {
    my ($xnsyns,$xgroup,$xsyns) = ADS::Abstracts::Index::readsyns($xsynfile, keepchars => 'A-Za-z,')
	or die "$script: cannot read synonym file $xsynfile\n";
    warn "$script: read ", $xnsyns, " synonym groups from file $xsynfile\n";

    # first exclude synonyms that are found in xclude file
    for (my $i = 1; $i <= $xnsyns; $i++) {
	next unless ($xsyns->[$i]);
	my @s = map { s/\s*,\s*(\w).*\Z/, $1/; $_ } @{$xsyns->[$i]};
	my ($g,$s,%osyns);
	foreach my $ns (@s) {
	    my $ng = $group->{$ns} or next;
	    if (not $g) {
		$g = $ng;
		$s = $ns;
		%osyns = map { ($_,0) } @{$syns->[$g]};
	    }
	    if (defined($osyns{$ns})) {
		$osyns{$ns} = $ng;
	    }
	    if ($g != $ng) {
		warn "synonyms \"$s\" and \"$ns\" are in different groups!\n";
	    }
	}
	next unless (%osyns);
	my %nsyns;
	foreach my $ns (sort keys %osyns) {
	    if ($osyns{$ns} > 0) {
		# syn is in group
		delete($osyns{$ns});
	    } else {
		warn "synonym \"$ns\" added to group for \"$s[0]\"\n";
		$nsyns{$ns} = $nsyns{$s[0]} = 1;
	    }
	}
	next unless (defined($syns->[$g]));
	
	if (%nsyns) {
	    $syns->[$g] = [ sort keys %nsyns ];
	} else {
	    $syns->[$g] = undef;
	}
    }
}

my %newsyns = ();
my $newg = 1;

for (my $i = 1; $i <= $nsyns; $i++) {
    next unless ($syns->[$i]);
    my @s = @{$syns->[$i]};
    if ($#s == 0) {
	# there is just one synonym here; no need for a group
	warn "$script: ignoring single synonym \"$s[0]\"\n";
	next;
    }
    my $gcount = 0;
    my %ns = ();
    my %ambiguous = ();
    my $name = {};
    while (@s) {
	my $w = shift(@s);
	my @a = ();
	$debug and warn "considering name \"$w\"\n";
	foreach my $ifh (@ifh) {
	    look($ifh,$w,0,0);
	    # accumulate all index entries for this synonym
	    while (my $r = <$ifh>) {
		my ($a,$rest) = split(/\t+/,$r);
		my $tail = $a;
		last unless ($tail =~ s/\A\Q$w\E//i);
		next if ($rest =~ /\A0\t/);
		$debug and warn "found name \"",$a,"\"\n";
		if ($name->{$tail}) {
		    push(@{$name->{$tail}},$w);
		} else {
		    $name->{$tail} = [ $w ];
		}
	    }
	}
    }

    foreach my $tail (sort keys(%{$name})) {
	my @fullnames = map { $_ . $tail } @{$name->{$tail}};
	if ($nosingle and $#fullnames == 0) {
	    # there is just one entry for this group, we can skip it
	    warn "$script: ignoring single expanded synonym \"$fullnames[0]\"\n";
	    next;	    
	}
	foreach my $f (@fullnames) {
	    $newsyns{$f} = $newg;
	}
	$newg++;
    }
}

my $tot = ADS::Abstracts::Index::writesyns(\*STDOUT,\%newsyns);
warn "written $tot new synonym groups to STDOUT\n";


