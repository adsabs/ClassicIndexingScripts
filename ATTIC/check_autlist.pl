#!/usr/bin/perl
#

use JSON;
use ADS::Abstracts::Entities;
use ADS::Abstracts::IO;

use integer;
use strict;
use warnings;

(my $script = $0) =~ s:^.*/::g;
my $ascii_enc = ADS::Abstracts::Entities::Recoder->new(Format => 'Text') or
    die __PACKAGE__, ": cannot create ascii encoder!";
my $json = JSON->new;
my $normalized = 0;
my $filenames = 0;
my $usage = "Usage: $script [--normalized] [--filenames] < index.status\n";

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $s = shift(@ARGV);
    if ($s eq '--normalized') {
	$normalized++;
    } elsif ($s eq '--filenames') {
	$filenames++;
    } else {
	die "$script: unknown option $s\n", $usage;
    }
}

while (<>) {
    my ($bib,$text) = split(/\t/);
    my $hash = $json->decode($text);
    my @meta = @{$hash->{abs}};
    my $autcount;
    while (@meta) {
	my $meta = shift(@meta);
	my $file = $meta->{p};
	my $abs = ADS::Abstracts::IO::ReadAbs($file);
	unless ($abs) {
	    warn "$script: $bib: error reading file $file\n";
	    next;
	}
	unless ($filenames) {
	    my $accno = (split(/\//,$file))[-1];
	    $accno =~ s/\.abs$//g;
	    $file = $accno;
	}
	my @a = split(/\s*\;\s+/,$ascii_enc->recode($abs->{AUT}));
	my $n = join("; ", map { normalize_author($_) } @a);
	$autcount->{$n} ||= [];
	push(@{$autcount->{$n}}, { f => $file, a => $abs->{AUT} });
    }
    my @k = keys %{$autcount};
    if (scalar(@k) > 1) {
	while (@k) {
	    my $k = shift(@k);
	    my @a = @{$autcount->{$k}};
	    while (@a) {
		my $a = shift(@a);
		if ($normalized) {
		    print join("\t", $bib,$a->{f},$k), "\n";
		} else {
		    print join("\t", $bib,$a->{f},$a->{a}), "\n";
		}
	    }
	}
    }
    
}

sub normalize_author {
    my $a = shift;

    s/\s+/ /;
    s/^\s*|\s*$//g;
    $a =~ s/[^A-Z0-9\,\']+/ /gi;
    if ($a =~ /,/) {
	$a =~ s/,\s*(\w).*/, $1/;
    }

    return lc($a);
}
