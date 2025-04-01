#!/usr/bin/perl
#
# converts index files to use offsets rather than bytes
#

use strict;
use integer;
select(*STDERR); $| = 1;
select(*STDOUT); $| = 1;

while (@ARGV) {
    my $file = shift(@ARGV);
    if ($file !~ /\.index$/ or
	$file eq 'soundex.index') {
	warn "skipping file $file\n";
	next;
    } 
    print STDERR "fixing file $file...";
    if ($file =~ /_pairs.index$/) {
	convert_binary_index($file);
    } else {
	convert_ascii_index($file);
    }
    print STDERR "done\n";
}

# get index count
sub convert_ascii_index {
    my $file = shift;
    open(my $fh,$file) or die "cannot open file $file: $!";
    open(my $oh,"> $file.new") or die "cannot open file $file.new: $!";
	
    my $r = <$fh>;
    print $oh $r;
    while (<$fh>) {
	chop;
	my ($t,$w,$c,$p,$sw,$sc,$sp) = split(/\t/);
	$c = $c / 4;
	$p = $p / 4;
	$sc = $sc / 4;
	$sp = $sp / 4;
	print $oh join("\t",$t,$w,$c,$p,$sw,$sc,$sp), "\n";
    }
    undef($fh);
    undef($oh);

    rename("$file.new",$file);
}

sub convert_binary_index {
    my $file = shift;
    open(my $fh,$file) or die "cannot open file $file: $!";
    open(my $oh,"> $file.new") or die "cannot open file $file.new: $!";
	
    my $buff;
    while(read($fh,$buff,20)) {
	my @l = unpack("N*",$buff);
	$l[3] = $l[3] / 4;
	$l[4] = $l[4] / 4;
	print $oh pack("N*", @l);
    }
    undef($fh);
    undef($oh);

    rename("$file.new",$file);
}

	
