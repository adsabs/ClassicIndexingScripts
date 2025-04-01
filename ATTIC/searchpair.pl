#!/usr/bin/perl
#
#
use strict;
use warnings;
use Search::Dict;
use Search::Binary;
use integer;

(my $script = $0) =~ s:^.*/::;
my $usage = "Usage: $script [OPTIONS] indexfile word1 word2
$script looks up word1 and word to in indexfile.index and then searches
indexfile_pairs.index for the occurances of this pair
OPTIONS:
  --bytes        index file contains byte offsets 
  --debug        print debugging information
  --idfile FILE  specify alternate document ID map (default: bib2accno.list).
";
my $recsize = 5 * length(pack("N",0));
my $idfile = 'bib2accno.list';
my $verbose = 1;
my $debug = 0;
my $bytes = 0;

die $usage unless (@ARGV);

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--bytes') {
        $bytes = 1;
    } elsif ($opt eq '--debug') {
        $debug = 1;
    } elsif ($opt eq '--idfile') {
        $idfile = shift(@ARGV) || '';
    } elsif ($opt eq '--help') {
        die $usage;
    } else {
        die $usage;
    }
}

if (@ARGV and $ARGV[0] eq '--idfile' and shift(@ARGV)) {
    $idfile = shift(@ARGV) || '';
}
die "$script: idfile $idfile not found!" unless (-f $idfile);
my $idmap = init_idfile($idfile) or 
    die "$script: error opening id file $idfile: $!";

my $index = shift(@ARGV) or die $usage;
$index .= ".index" unless ($index =~ /\.index$/);
die "$script: index file $index not found" unless (-f $index);
open(my $ifh, $index) or die "$script: cannot open file $index: $!";

my $word1 = uc(shift(@ARGV)) or die $usage;
my $word2 = uc(shift(@ARGV)) or die $usage;
die $usage if (@ARGV);

my $pairindex = $index; $pairindex =~ s:\.index$:_pairs.index:;
my $pairlist  = $index; $pairlist  =~ s:\.index$:_pairs.list:;

my $id1 = get_word_id($ifh,$word1) or die "cannot find $word1 in $index";
my $id2 = get_word_id($ifh,$word2) or die "cannot find $word2 in $index";
warn "word id for $word1 is $id1\n" if ($verbose);
warn "word id for $word2 is $id2\n" if ($verbose);

my @ids = find_wordpair($pairindex,$pairlist,$id1,$id2);
my @docs = id2doc($idmap,@ids);
print @docs;

sub id2doc {
    my $map = shift;
    my $fh = $map->{fh};
    my @docs;

    while (@_) {
	my $lineno = shift;
	my $pos = $map->{offs} + $lineno * $map->{reclen};
	seek($fh,$pos,0);
	my $line = <$fh>;
	push(@docs,$line);
    }
    
    return @docs;
}

sub init_idfile {
    my $file = shift;
    open(my $fh, $file) or return undef;
    my $size = -s $file;

    # first like contains line count
    my $line = <$fh>;
    my $offs = length($line);
    $line =~ s/^\s+|\s+$//g;
    my ($count,$bytes) = split(/\s+/,$line);
    my $reclen = ($size - $offs) / $count;

    return { fh => $fh, reclen => $reclen, count => $count, offs => $offs };
}

sub find_wordpair {
    my $pi = shift;
    my $pl = shift;
    my $id1 = shift;
    my $id2 = shift;

    open(my $pfh,$pi) or die "cannot open input file $pi: $!";
    open(my $lfh,$pl) or die "cannot open input file $pl: $!";

    my $buff = [ $id1, $id2 ];
    my $nrec = (-s $pi) / $recsize;
    my $rec = binary_search(0,$nrec,$buff,\&cmp_pairrec,$pfh);
    return () unless ($rec);
    unless ($bytes) {
	$rec->[3] *= 4;
	$rec->[4] *= 4;
    }
    warn "record: $rec->[0] $rec->[1], score=$rec->[2], bytes=$rec->[3], ",
    "offset=$rec->[4]\n" if ($verbose);
    return () unless ($id1 eq $rec->[0] and $id2 eq $rec->[1]);
    seek($lfh,$rec->[4],0);
    read($lfh,$buff,$rec->[3]) or return ();

    return unpack ("N*",$buff);
}

sub read_pairrec {
    my $fh = shift;
    my $pos = shift;

    seek($fh,$pos * $recsize,0) if (defined($pos));
    my $buff;
    read($fh,$buff,$recsize) or die "cannot read $recsize bytes from fh: $!";
    return unpack("N*",$buff);
}

sub cmp_pairrec {
    my $fh = shift;
    my $target = shift;
    my $pos = shift;

    my @val = read_pairrec($fh,$pos);
    warn "target: ",$target->[0]," ",$target->[1],"; val: $val[0] $val[1]\n"
	if ($debug);
    my $cmp = ($target->[0] <=> $val[0]) || ($target->[1] <=> $val[1]);
    if ($cmp) {
	return ($cmp,$pos++);
    } else {
	return ($cmp,[@val]);
    }
}

sub get_word_id {
    my $fh = shift;
    my $word = shift;

    look($fh,$word,0,0);
    my $e = <$fh>; chop($e);
    warn "found entry $e\n" if ($verbose);
    my ($term,@rest) = split(/\t/,$e);
    return undef unless ($term eq $word);
    return $rest[-1];
}


