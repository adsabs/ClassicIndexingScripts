#!/usr/bin/perl

use strict;
use integer;
use warnings;
use constant { NORMALIZATION => 5000 };

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script --ntot NTOT [--bytes] [--debug] index_file [...]
$script adds the score column to the input index file
EOF
    ;

my $debug = 0;
my $ntot = 0;
my $factor = 1;

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--debug') {
	$debug = 1;
    } elsif ($opt eq '--bytes') {
	$factor = length(pack("N", 1));
    } elsif ($opt eq '--ntot') {
        $ntot = shift(@ARGV);
    } elsif ($opt eq '--help') {
	die $usage;
    } else {
	die "$script: unrecognized option $opt\n", $usage;
    }
}
die $usage unless(@ARGV);
die "$script: must supply total number of document via --ntot flag" 
    unless ($ntot);

warn "$script: execution starting at ", scalar localtime(time), "\n";

# now compute factors uses in calculating the scores (see function wordscore)
my ($NORM_FACTOR,$OFFS_FACTOR);
{   no integer; 
    $NORM_FACTOR = NORMALIZATION / log(10); 
    $OFFS_FACTOR = log($ntot);
}
warn "$script: NORM_FACTOR = ", $NORM_FACTOR, 
    "; OFFS_FACTOR = ", $OFFS_FACTOR, "\n" if ($debug);
# array caching computed word scores; we initialize
# the first two entries to 0 
my %scorecache = (); 
 
# since we store the score as a 16-bit quantity,
# the maximum number of documents we can index using this score
# function before there is a 16-bit overflow is
#     Smax = 10 ^ (2^16 / NORMALIZATION)
# i.e. 10^13 documents 
# we used to worry about this but no more.
#if ($ntot >= 3577667) {
#    die "$script: maximum document size reached, we cannot generate an ",
#    "index without changes in the search engine software\n",
#    "$script: please see the documentation on word scoring for more info\n";
#} elsif ($ntot > 3000000) {
#    warn "$script: warning: we are getting close to maximum number of ",
#    "documents that can be indexed with the current architecture (3.57M)\n",
#    "$script: please see the documentation on word scoring for more info\n";
#}

while (@ARGV) {
    my $file  = shift(@ARGV) or die $usage;
    my $ofile = "$file.new";
    open(my $fh, $file) 
	or die "$script: cannot open input file $file: $!";
    open(my $ofh, "> $ofile") 
	or die "$script: cannot open output file $ofile: $!";
    warn "$script: processing file $file at ", scalar localtime(time), "\n";

    my $record;
    my $fmt;
    while (defined($record = <$fh>)) {
	chop($record);
	# @rest may contain synonym group (for text and title)
	my ($word,$bytes,$offs,$sbytes,$soffs,@rest) = split(/\t/,$record);
	next unless (defined($soffs));
	my $score  = $scorecache{$bytes} ||= wordscore($bytes);
	my $sscore =  $scorecache{$sbytes} ||= wordscore($sbytes);
	$bytes *= $factor;
	$sbytes *= $factor;
	$offs *= $factor;
	$soffs *= $factor;
	$fmt ||= "%s" . "\t%u" x (6 + scalar(@rest)) . "\n";
 	printf $ofh ($fmt,$word,$score,$bytes,$offs,$sscore,$sbytes,
		     $soffs,@rest) or
	     die "$script: error writing entry for \"$word\" to index file";
    }
    
    close($fh); close($ofh);
    rename($ofile,$file) or
	die "$script: cannot rename $ofile to $file: $!";

    warn "$script: processed file $file at ", scalar localtime(time), "\n";
}


# wordscore is given as input the number of bytes for this 
# Computes the score of each word indexed according to the formula:
#    score = Log(Nt/Nw)
# where:
#    Log: log base 10
#    Nt : number of total entries in database
#    Nw : number of accnos containing this word
# since we store the score in an unsigned short (16 bits), this breaks
# down when the score greater than 65,536, i.e. when the total number
# of documents is greater than 3,577,667
sub wordscore {
    no integer;
    return 0 unless ($_[0]);
    return int (0.5 + $NORM_FACTOR * ($OFFS_FACTOR - log($_[0])));
}
