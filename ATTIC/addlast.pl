#!/usr/bin/perl
#
# $Id$
#
# Adds last names to author index
#
# $Log$
#


use strict;
use integer;
use warnings;

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script adds the last name entries to the author_index file
EOF
    ;
my $debug = 0;
my $syndir = ".";
my $ntot = 0;

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--help') {
	die $usage;
    } elsif ($opt eq '--ntot') {
        $ntot = shift(@ARGV);
    } elsif ($opt eq '--debug') {
        $debug = 1;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}

die $usage unless(@ARGV);
# now compute factors uses in calculating the scores (see function wordscore)
my $SIZEOFLONG  = length(pack("N", 1));

warn "$script: execution starting at ", scalar localtime(time), "\n";

my $indexfile = shift;
open(my $ifh, $indexfile) or 
    die "$script: error reading index file $indexfile: $!";
my $newindex = $indexfile . ".new";
open(my $oifh, "> $newindex") or 
    die "$script: error opening output file $newindex: $!";

my %records = readindex($indexfile) or 
    die "$script: could not read index file $indexfile";
my @words = sort keys %records;
# now create hash of last names with associated groups of
# first name synonyms
my ($w,%names,%synonyms);
foreach $w (@words) {
    (my $last = $w) =~ s/,.*$//;
    next unless $last;
    if ($names{$last}) {
	push(@{$names{$last}},$w);
    } else {
	$names{$last} = [ $w ];
    }
}

# now open list file
my $listfile = $indexfile; $listfile =~ s/\.index$/.list/;
open(my $lfh, $listfile) or 
    die "$script: cannot open list file $listfile: $!";
my $offset = (-s $listfile) / $SIZEOFLONG;
my $newlist = $listfile . ".new";
open(my $olfh, "> $newlist") or
    die "$script: cannot open output list file $newlist: $!";

my @lastwords = sort keys %names;
my $last;
while (defined($last = shift(@lastwords))) {
    # skip if we've processed this entry already
    my $lastname = $names{$last};
    next unless (defined($lastname));
    my @names = @{$lastname};

    my @lastrec = (0, 0, 0, 0);
    my $tread = 0;
    my $sread = 0;
    my (%terms,%syns);
    while (@names) {
	my $name = shift(@names);
	my $rec = $records{$name};
	if ($rec->[0]) {
	    @terms{readlistblock($lfh,$rec->[0],$rec->[1])} = ();
	    $lastrec[0] = $rec->[0];
	    $lastrec[1] = $rec->[1];
	    $tread++;
	}
	if ($rec->[2]) {
	    @syns{readlistblock($lfh,$rec->[2],$rec->[3])} = ();
	    $lastrec[2] = $rec->[2];
	    $lastrec[3] = $rec->[3];
	    $sread++;
	}
    }
    if ($tread == 0) {
	warn "$script: warning: no term entry for last name $last\n"
	    if ($debug);
	$lastrec[0] = $lastrec[1] = 0;
    } elsif ($tread == 1) {
	# the entries for lastrec are already set from above
	warn "$script: warning: term block for last name $last not needed\n"
	    if ($debug);
    } else {
	# there is more than one entry that we are merging here
	my $count = writelistblock($olfh,keys %terms);
	die "$script: cannot write $count count to list file"
	    unless ($count);
	$lastrec[0] = $count; 
	$lastrec[1] = $offset;
	$offset += $count;
    }
    if ($sread == 0) {
	warn "$script: warning: no synonym entry for last name $last\n"
	    if ($debug);
	$lastrec[2] = $lastrec[3] = 0;
    } elsif ($sread == 1) {
	# the entries for lastrec are already set from above
	warn "$script: warning: syn  block for last name $last not needed\n"
	    if ($debug);
    } else {
	# there is more than one entry that we are merging here
	my $count = writelistblock($olfh,keys %syns);
	die "$script: cannot write $count count to list file"
	    unless ($count);
	$lastrec[2] = $count; 
	$lastrec[3] = $offset;
	$offset += $count;
    }

    print $oifh join("\t", $last, @lastrec), "\n";
}

# now add all first-name entries to the index file
while (defined($w = shift(@words))) {
    # make sure we skip this if we have a last name entry that 
    # somehow matches this already
    next if ($names{$w});
    my @firstrec = @{$records{$w}};
    # delete last entry (synonym id)
    pop(@firstrec);
    print $oifh join("\t", $w, @firstrec), "\n";
}

close($ifh);
close($lfh);
close($oifh);
close($olfh);

# now update the index and list files
die "$script: cannot sort file $newindex: $!"
    if (system("sort -T . -o $newindex $newindex"));
rename($newindex,$indexfile) or 
    die "$script: cannot rename file $newindex to $indexfile: $!";
die "$script: cannot add new list entries to list file $listfile: $!"
    if (system("/bin/cat $newlist >> $listfile"));
unlink($newlist) or 
    die "$script: cannot remove file $newlist: $!";

warn "$script: execution ended at ", scalar localtime(time), "\n";

# $count = writeblock($listfh,@ids)
sub writelistblock {
    my $fh = shift;
    my @ids = sort { $a <=> $b } @_;
    print $fh pack("N*",@ids) or return 0;
    return scalar(@ids);
}

# @ints = readblock($listfh,$count,$offset)
sub readlistblock {
    my $fh = shift;
    my $bytes = $SIZEOFLONG * shift;
    my $offset = $SIZEOFLONG * shift;
    my $buff;

    return () unless ($bytes);
    seek($fh,$offset,0);
    read($fh,$buff,$bytes) or
	die "$script: error reading ", $bytes, 
	" bytes at offset ", $offset, " from listfile";
    
    unpack("N*",$buff);
}

sub readindex {
    my $file = shift;
    open(my $fh, $file) or return ();
    my %records = ();

    while (my $r = <$fh>) {
	chop($r);
	my ($word,@rest) = split(/\t+/,$r);
	$records{$word} = [ @rest ];
    }
    return %records;
}
