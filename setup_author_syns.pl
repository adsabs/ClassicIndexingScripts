#!/usr/bin/perl
#
#

use strict;
use ADS::Abstracts::Index;

my $script = $0; $script =~ s:^.*/::;
my $usage = "Usage: $script author.syn\n";

my $file = shift(@ARGV) or die $usage;
(-f $file) or die $usage;

my($n,$syns) = ADS::Abstracts::Index::readsyns($file);
warn "$script: read $n synonym groups from $file\n";

my %ns = map { 
    (ADS::Abstracts::Index::Tokenizer::canonize_authors_full($_),$syns->{$_}) 
    } keys %{$syns};

my $nn = ADS::Abstracts::Index::writesyns($file,\%ns);

warn "$script: written $nn new synonym groups to $file\n";

