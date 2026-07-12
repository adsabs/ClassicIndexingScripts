#!/usr/bin/perl
my $base = shift(@ARGV); 
my $deleted = "$base/bibcodes.deleted";
my $alternate = "$base/bibcodes.alternate";
open(my $dh, "> $deleted") or die "cannot open output file $deleted: $!";
open(my $ah, "> $alternate") or die "cannot open output file $alternate: $!";
while (<STDIN>) {
    my ($o,$n) = split;
    next unless $o;
    $n ||= "";
    if ($n) {
        print $ah $o, "\t", $n, "\n";
    } else {
        print $dh $o, "\n";
    }
}
