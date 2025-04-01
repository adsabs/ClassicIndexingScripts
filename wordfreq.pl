#!/usr/bin/perl
#
# wordfreq.pl --bytes ../../load/current/author.index < author_file > author.freq
#
# Appends a frequency count found in the index to the list
# of words in the input file.

use strict;
use warnings;
use integer;
use ADS::Abstracts::Index;

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script [--bytes] [--debug] index_file < word_file > word.freq
EOF
    ;

my $debug = 0;
my $factor = 1;

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--bytes') {
        $factor = length(pack("N", 1));
    } elsif ($opt eq '--help') {
        die $usage;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}
die $usage unless(@ARGV);
my $file = shift(@ARGV);

my %index = ADS::Abstracts::Index::readindex($file);

my ($entry, $freq);
while (defined($entry = <STDIN>)) {
    $entry =~ s/^\s*|\s*$//g;
    my $i = $index{$entry};
    if ($i) {
	$freq = $i->[1] / $factor;
    } elsif ($entry) {
	$freq = 0;
    } else {
	$freq = '';
    }

    print "$entry\t$freq\n";
}


