#!/usr/bin/perl
#
# $Id: mkpart.pl,v 1.1 2003/05/27 19:59:15 ads Exp ads $
#
# Removes ending part of term in first column and joins consecutive
# entries
#
# $Log: mkpart.pl,v $
# Revision 1.1  2003/05/27 19:59:15  ads
# Initial revision
#
#
#

use strict;
#use warnings;

my $script = $0;
$script =~ s:^.*/::;
my $count = 1;
my $part = '';
my @items = ();

while (@ARGV and $ARGV[0] =~ /^-/) {
    my $s = shift(@ARGV);
    if ($s =~ /^--?part/) {
	$part = shift(@ARGV);
    } elsif ($s =~ /^--?count/) {
	$count = shift(@ARGV);
    } else {
	die "Usage: $script [--count n] [--part char] [file] ...\n";
    }
}

# do first entry
my ($oldword,$rest,$c);
while (not defined($oldword)) {
    last unless ($_ = <>);
    chop;
    next unless ($_);
    ($oldword,$rest) = split(/\t/,$_,2);
    next unless ($oldword);
    $oldword =~ s/$part.*$// if ($part);
    if ($oldword) {
	@items = ($oldword);
	push(@items,$rest) if ($rest);
	$c = 1;
    }
}

while (<>) {
    chop;
    my $word;
    ($word,$rest) = split(/\t/,$_,2);
    $word =~ s/$part.*$// if ($part);
    next unless ($word);
    if ($word ne $oldword) {
	print join("\t",@items),"\n" if ($c >= $count);
	@items = ($word);
	$oldword = $word;
	$c = 0;
    } 
    push(@items,$rest) if ($rest);
    $c++;
}

print join("\t",@items),"\n";
