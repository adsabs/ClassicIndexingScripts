#!/usr/bin/perl
#

use strict;
use warnings;
use integer;
(my $script = $0) =~ s:^.*/::;
my $idfile = 'bib2accno.list';

select(STDERR); $| = 1;
select(STDOUT); $| = 1;

if (@ARGV and $ARGV[0] eq '--idfile') {
    shift(@ARGV);
    $idfile = shift(@ARGV);
}

open(my $fh, $idfile) or 
    die "cannot open $idfile: $!";
my $line = <$fh>;
$line =~ s/^\s+|\s+$//g;
my ($count) = split(/\s+/,$line);
undef($fh);

warn "id file $idfile has $count lines\n";

my ($file, $buff);
while ($file = shift(@ARGV)) {
    my $offset = 0;
    my $err = 0;
    my $rec = 0;
    warn "checking file $file...";
    open(my $fh, $file) or 
	die "cannot open file $file: $!";
    while(read($fh,$buff,4)) {
	$rec++;
	my $n = unpack("N",$buff);
	if ($n < 0 or $n >= $count) {
	    warn "bad record id $n found at offset $offset\n";
	    $err++;
	}
	$offset += 4;
    }
    if ($err) {
	warn "found $err errors in $rec records!\n";
    } else {
	warn "found $rec records -- ok\n";
    }
    undef($fh);
}
	
    
