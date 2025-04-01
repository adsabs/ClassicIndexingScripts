#!/usr/bin/perl
#
# $Id: setup_index_cache.pl,v 1.1 2003/01/03 20:49:22 ads Exp ads $
#
# Sets up the index cache
#
# Usage: setup_index_cache.pl dir1 dir2
#
# $Log: setup_index_cache.pl,v $
# Revision 1.1  2003/01/03 20:49:22  ads
# Initial revision
#
#

use strict;
use integer;
use warnings;

my $script = $0; $script =~ s:^.*/::;
my $debug = 0;

my $usage = <<EOF;
$script [OPTIONS] origin_dir destination_dir
This program checks whether entries containing pre-parsed fields
created during indexing can be used in the current index by
comparing whether the cached metadata is still up to date and
if each parsed entry from the document list is still up to date
Options are:
   --help              print this message and exit
   --doclist LIST      input list of documents to index
   --cachelist LIST    input list of entries available from cache
EOF

my ($accnolist,$cachelist);

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--doclist') {
	$accnolist = shift(@ARGV);
    } elsif ($opt eq '--cachelist') {
	$cachelist = shift(@ARGV);
    } elsif ($opt eq '--debug') {
	$debug++;
    } elsif ($opt eq '--help') {
	die $usage;
    } else {
	die "$script: unknown option `$opt'!\n", $usage;
    }
}


# first check to see if files in dir1/config and dir2/config match
# (these is the metadata used in the indexing process)
my $odir = shift(@ARGV) or die $usage;
my $ddir = shift(@ARGV) or die $usage;
die $usage if (@ARGV);

# now figure out which entries can be copied from the cache
$cachelist ||= "$odir/accnos.done";
$accnolist ||= "$ddir/accnos.input";

unless (-f $accnolist) {
    warn "$script: input accno list $accnolist not found, disabling cache";
    exit(1);
}

my $origin = read_dir("$odir/config") or 
    die "$script: cannot check files in $odir/config";
my $destination = read_dir("$ddir/config") or 
    die "$script: cannot check files in $ddir/config";

unless (-f $cachelist) {
    warn "$script: input accno list $cachelist not found, disabling cache";
    exit(1);
}
unless (hash_eq($origin,$destination)) {
    warn "$script: config directories $odir/config and $ddir/config ",
    "have different contents, disabling caching\n";
    exit(1);
}

open(my $ifh, $accnolist) or
    die "$script: cannot open input file $accnolist";
my $alist = read_accnolist($ifh);
warn "$script: read ", scalar keys %$alist, " entries from $accnolist\n";

open(my $cfh, $cachelist) or
    die "$script: cannot open cache list file $cachelist";
my $clist = read_accnolist($cfh);
warn "$script: read ", scalar keys %$clist, " entries from $cachelist\n";

my $additions = $accnolist . ".todo";
open(my $addfh, "> $additions") or 
    die "$script: cannot open output file $additions: $!";

my $addcache = $accnolist . ".cache";
open(my $cachefh, "> $addcache") or 
    die "$script: cannot open output file $addcache: $!";

my ($k,$v);
while (($k,$v) = each(%$alist)) {

    my $cv = delete($clist->{$k});
    unless ($v->{f}) {
        # this entry should not get indexed
        next;
    }
    unless (defined($cv)) {
        # entry is not in cached list, put it in additions
        print $addfh $k, "\t", $v->{f}, "\n";
        next;
    }
    unless ($cv->{f}) {
        # entry was not indexed in cache, put it in additions
        print $addfh $k, "\t", $v->{f}, "\n";
        next;
    }
    if ($v->{t} > $cv->{t}) {
        # file is more recent than cached entry
        print $addfh $k, "\t", $v->{f}, "\n";
        next;
    }
    # if we got here is because the cache is still valid
    print $cachefh $k, "\n";
}

close($addfh);
close($cachefh);
exit(0);

sub hash_eq {
    my %h1 = %{ $_[0] };
    my %h2 = %{ $_[1] };
    my @k1 = sort keys %h1;
    my @k2 = sort keys %h2;

    unless ($#k1 == $#k2) {
	warn "$script: number of elements in config hashes differ\n";
	return 0;
    }
    while (@k1 and @k2) {
	my $k1 = shift(@k1);
	my $k2 = shift(@k2);
	unless ($k1 eq $k2) {
	    warn "$script: key $k1 differs from key $k2\n";
	    return 0;
	}
	unless ($h1{$k1} eq $h2{$k2}) {
	    warn "$script: contents of $k1 differ from $k2\n";
	    return 0;
	}
    }
    return 1;
}

sub read_dir {
    my $dir = shift;
    my %files = ();

    -d $dir or return ();
    opendir(my $dh, $dir) or return ();
    my @files = grep { -f "$dir/$_" } readdir($dh);
    warn "files are: ", join(", ",@files), "\n" if ($debug);
    while (@files) {
	my $file = shift(@files);
	open(my $fh, "$dir/$file") or 
	    die "$script: cannot open file $dir/$file: $!";
	$files{$file} = join('',<$fh>);
    }

    return \%files;
}

sub read_accnolist {
    my $fh = shift;
    my $hash = {};
    local $_;

    while (<$fh>) {
	my ($a,$f,$t) = split;
	next unless ($a and $f);
	$hash->{$a} = { f => $f, t => 0 + $t };
    }

    return $hash;
}
