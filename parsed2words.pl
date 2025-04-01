#!/usr/bin/perl
#
# $Id: parsed2words.pl,v 1.3 2006/04/27 13:46:30 ads Exp ads $
# 
# This script translates parsed files (*.parsed) into words files by
# replacing the document identifiers in the first column with 
# sequential number identifiers (corresponding to the line numbers
# in the bib2accno.list file).
#
# $Log: parsed2words.pl,v $
# Revision 1.3  2006/04/27 13:46:30  ads
# Fixed bug that was creating records with one identifier but no content,
# which upset mkindex later on.
#
# Revision 1.2  2006/04/24 18:13:41  ads
# Removed records longer than $MAXLEN bytes.
#
# Revision 1.1  2006/04/24 17:45:17  ads
# Initial revision
#
#

use strict;
use warnings;
use integer;

(my $script = $0) =~ s:^.*/::;

my $usage = <<EOF;
Usage: $script [OPTIONS] parsed_file [...] < bib2accno.list
$script translates parsed files (*.parsed) into words files by
replacing the document identifiers in the first column with 
sequential number identifiers (corresponding to the line numbers
in the bib2accno.list file).
EOF
    ;

# maximum length for a record to be retained
my $MAXLEN = 200; 

my $ignorefile;
my $debug = 0;
while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--ignore') {
        $ignorefile = shift(@ARGV);
    } elsif ($opt eq '--help') {
        die $usage;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}
die $usage unless(@ARGV);

warn "$script: execution starting at ", scalar localtime(time), "\n";
warn "$script: reading identifier list from STDIN...\n";
my %bib2id = read_ids(\*STDIN);
my $ntot = scalar keys %bib2id;
warn "$script: read $ntot identifiers\n";

my %ignore = ();
if ($ignorefile) {
    die "$script: ignore file $ignorefile not found" 
        unless (-f $ignorefile);
    open(my $fh, $ignorefile) or 
        die "$script: cannot open file $ignorefile: $!";
    %ignore = read_ids($fh);
    warn "$script: read ", scalar keys %ignore, 
    " ids to ignore from $ignorefile\n";
}

while (@ARGV) {
    my $file  = shift(@ARGV) or die $usage;
    open(my $fh, $file) or die "$script: cannot open input file $file: $!";
    warn "$script: processing file $file at ", scalar localtime(time), "\n";

    (my $outfile = $file) =~ s/\.parsed$/.words/;
    open(my $ofh, "> $outfile") or 
	die "$script: cannot open output file $outfile: $!";
    
    my $written = 0;
    my $record;

    while (defined($record = <$fh>)) {
	chop($record);
	my ($accno,@rest) = split(/\t/,$record);
	next unless (@rest);
        my $recno = $bib2id{$accno};
        unless (defined($recno)) {
            warn "$script: no id found for identifier `$accno' (skipped)";
            next;
        }
        if (defined($ignore{$accno})) {
            warn "$script: skipping entry for record $accno\n" if ($debug);
            next;
        }

	my $written_id = 0;
	while (@rest) {
	    my $r = shift(@rest);
	    if (length($r) > $MAXLEN) {
		warn "$script: $file: $accno: skipped long record: $r\n";
	    } else {
		$written += print $ofh $recno unless ($written_id++);
		print $ofh "\t", $r;
	    }
	}
	print $ofh "\n" if ($written_id);
    }

    die "$script: cannot sort file $outfile: $!"
	if (system("sort -T . -n -o $outfile $outfile"));
    warn "$script: written $written records to file $outfile at ",
    scalar localtime(time), "\n";
}

warn "$script: script ending at ", scalar localtime(time), "\n";

sub read_ids {
    my $fh = shift;
    my %lineno = ();
    my $n = 0;
    local $_;

    while (<$fh>) {
        my ($id) = split;
        next unless ($id);
        $lineno{$id} = $n++;
    }

    return %lineno;
}

