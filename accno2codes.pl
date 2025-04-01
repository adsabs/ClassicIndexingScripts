#!/usr/bin/perl
#
# $Id$
#
# Converts *_codes.accnos files into the respective *_codes files
#
# $Log$
#

(my $script = $0) =~ s:^.*/::g;
use integer;
use strict;
use warnings;

my $usage = <<"EOF";
Usage: $script [OPTIONS] file.accnos [...] < bib2accno.list
where file.accnos [...] is one of the _codes files with accnos in them
    --debug            turn debugging on
EOF
    ;
my $debug = 0;
sub pdebug { 1 };

while (@ARGV and $ARGV[0] =~ /^\-\-/) {
    local $_ = shift(@ARGV);
    if (/^\-\-debug/) {
	undef &pdebug;
	eval 'sub pdebug { print STDERR "$script: ", @_; }';
	$debug = 1;
    } elsif (/^--help/) {
	die $usage;
    } else {
	die "$script: unknown option $_\n", $usage;
    }
}

my %accno2bib = &read_b2a(\*STDIN);

while (@ARGV) {
    my $input = shift(@ARGV);
    my $output = $input; 
    my ($fh,$ofh);
    unless ($output =~ s/\.accnos$//) {
	warn "$script: file $input since it does not end with ",
	    "suffix `.accnos' (skipped)\n";
	next;
    }
    unless (open($fh,$input)) {
	warn "$script: cannot open input file $input: $! (skipped)";
	next;
    }
    unless (open($ofh,">$output")) {
	die "$script: cannot open input file $output: $! (skipped)";
	next;
    }
    print $ofh map { s/\s+//g; ($accno2bib{$_},"\n") } <$fh>;
}

sub read_b2a {
    my $fh = shift;
    my %hash;
    local $_;

    while (<$fh>) {
	my ($b,$a,@rest) = split;
	next unless (@rest);
	$hash{$a} = $b;
    }
    return %hash;
}

