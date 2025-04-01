#!/usr/bin/perl
#
# $Id: addsyns.pl,v 1.3 2003/12/15 19:51:16 ads Exp ads $
#
# Adds synonyms to an index and list file
#
# $Log: addsyns.pl,v $
# Revision 1.3  2003/12/15 19:51:16  ads
# Modified output to index file to use function fmtrecord() which
# forces all integers to be output as unsigned long.
# This is a stopgap measure that will keep our offsets working ok
# from 2GB to 4GB.  Then we're still screwed.
#
# Revision 1.2  2003/11/06 21:36:53  ads
# Rewritten to use less core memory.  Instead of reading the entire
# index file into one big hash we process the file sequentially and
# then seek into it to look for synonyms.  This allows us to index
# much larger files.
#
# Revision 1.1  2002/12/30 15:20:36  ads
# Initial revision
#
#


use strict;
use integer;
use warnings;
use Search::Dict;

my $script = $0; $script =~ s:^.*/::;
my $usage = <<EOF;
$script [--configdir SYNDIR] index_file [...] 
$script adds the synonym column to an index file.
This is accomplished in one of two ways:
- if a synonym file corresponding to the index in question is found
  in DIR, then all entries for each word's synonyms are computed and 
  appended to the list file
- if no synonym file is found, then the synonym columns are simply
  a duplication of the regular word's columns
Assuming the input index file is named FIELD.index, this script will
look in SYNDIR for a synonym file named FIELD.syn, and if found the
computation of synonyms will be turned on.
EOF
    ;
my $debug = 0;
my $syndir = ".";
my $SIZEOFLONG  = length(pack("N", 1));

while (@ARGV and $ARGV[0] =~ /^--/) {
    my $opt = shift(@ARGV);
    if ($opt eq '--help') {
	die $usage;
    } elsif ($opt eq '--configdir') {
        $syndir = shift(@ARGV);
    } elsif ($opt eq '--debug') {
        $debug = 1;
    } else {
        die "$script: unrecognized option $opt\n", $usage;
    }
}

die $usage unless(@ARGV);
warn "$script: execution starting at ", scalar localtime(time), "\n";

while (@ARGV) {
    my $indexfile = shift;
    open(my $ifh, $indexfile) or 
	die "$script: error reading index file $indexfile: $!";
    my $newindex = $indexfile . ".new";
    open(my $oifh, "> $newindex") or 
	die "$script: error opening output file $newindex: $!";
   
    warn "$script: processing index file $indexfile at ", 
    scalar localtime(time), "\n";
    my $synfile = $indexfile;
    $synfile =~ s/\.index$/.syn/; $synfile =~ s:^.*/::;
    $synfile = $syndir . '/' . $synfile;
    
    unless (-f $synfile) {
	# if there are no synonyms, simply output the same columns
	while (my $r = <$ifh>) {
	    chop($r);
	    my ($word,$rest) = split(/\t+/,$r,2);
	    print $oifh join("\t",$word,$rest,$rest), "\n";
	}
	warn "$script: no synonym file found for file $indexfile\n";
	rename($newindex,$indexfile) or 
	    die "$script: cannot rename file $newindex to $indexfile: $!";
	next;
    }
 
    my ($syngroups,$synnum,$synonyms) = readsyns($synfile) or 
	die "$script: error reading synonym file $synfile: $!";
    warn "$script: read ", $syngroups, " synonym groups from file $synfile\n";

    # now open list file
    my $listfile = $indexfile; $listfile =~ s/\.index$/.list/;
    open(my $lfh, $listfile) or 
	die "$script: cannot open list file $listfile: $!";
    my $offset = (-s $listfile) / 4;
    my $newlist = $listfile . ".new";
    open(my $olfh, "> $newlist") or
	die "$script: cannot open output list file $newlist: $!";

    my ($w,$rec);
    while (($w,$rec) = readrecord($ifh)) {
	my $num = $synnum->{$w};

	warn "$script: processing record for $w\n" if ($debug);

	if (not defined($num)) {
	    # this word does not have synonyms, so we create new syngroup
	    # number and just output existing entries
	    $syngroups++;
	    print $oifh &fmtrecord($w, @{$rec}, @{$rec}, $syngroups);
	    warn "$script: word \"$w\" has no synonyms\n" if ($debug);
	    next;
	} elsif ($num == 0) {
	    # skip if we've processed this entry already
	    warn "$script: synonym \"$w\" has been processed already\n" 
		if ($debug);
	    next;
	} 
	  
	# ok, this word belongs to a synonym group, so we'll
	# process all entries in this group below;
	# first gather up entries from its synonyms and create entry for
	# this synonym group
	my @syns = @{$synonyms->[$num]};
	my ($buff,$syn,%saw,%synset);
	my $nread = 0;
	my $filepos = tell($ifh);
	foreach $syn (@syns) {
	    # first of all zero out the group number so we won't
	    # reprocess any of these synonym entries a second time
	    $synnum->{$syn} = 0;

	    # if this synonym does not appear in the index,
	    # we create an entry in which the word bytes and pointer
	    # are set to 0 but we still include it in the index so 
	    # that it is found when searches with synonyms are used
	    $synset{$syn} = findrecord($ifh,$syn);
	    if ($synset{$syn}) {
		warn "$script: found record for \"$syn\" (", 
		$synset{$syn}->[0], " records)\n" if ($debug);
		seek($lfh, 4 * $synset{$syn}->[1], 0);
		read($lfh, $buff, 4 * $synset{$syn}->[0]) or
		    die "$script: error reading ", $synset{$syn}->[0], 
		    " entries at offset ", $synset{$syn}->[1], 
		    " from file $listfile: $!";
		$nread++;
		@saw{unpack("N*",$buff)} = ();
	    } else {
		warn "$script: no index record found for word \"$syn\"\n"
		    if ($debug);
		$synset{$syn} = [ 0, 0 ];
	    }
	}
	seek($ifh,$filepos,0);

        my @syncolumn = ();
        if ($nread == 0) {
            warn "$script: something wrong happened while processing ",
            "synonyms for word \"$w\"\n";
        } elsif ($nread > 1) {
            # we found several words belonging to the same synonym group;
            # join all entries together and write a new block out 
            my @ids = sort { $a <=> $b } keys %saw;
            my $count = scalar @ids;
            print $olfh pack("N*",@ids) or
                die "$script: error writing ", $count, " longs to list file ",
                $newlist, ": $!";
            @syncolumn = ($count, $offset);
            $offset += $count;
        } else {
            # there was only one entry in the index belonging to this
            # synonym group, which means we can simply point all its
            # synonyms to the block in the list file containing the
            # identifiers rather than create a new one
            @syncolumn = (@{$rec});
        }
        foreach $syn (@syns) {
	    print $oifh &fmtrecord($syn,@{$synset{$syn}},@syncolumn,$num);
        }
    }

    close($ifh);
    close($lfh);
    close($oifh);
    close($olfh);
    # now update the index and list files
    rename($newindex,$indexfile) or 
	die "$script: cannot rename file $newindex to $indexfile: $!";
    die "$script: cannot add new list entries to list file $listfile: $!"
	if (system("/bin/cat $newlist >> $listfile"));
    unlink($newlist) or 
	die "$script: cannot remove file $newlist: $!";
}

warn "$script: execution ended at ", scalar localtime(time), "\n";


sub fmtrecord {
    # we use fprintf because we need to force integers to be
    # printed as unsigned longs.  Dunno if there is a better way to do this
    # my ($word, $bytes, $offset, $synbytes, $synoffset, $num);
    sprintf "%s\t%u\t%u\t%u\t%u\t%u\n", @_;
}

sub readrecord {
    my $fh = shift;
    my $r = <$fh>;
    return () unless defined($r);
    chop($r);
    my ($w,@rest) = split(/\t+/,$r) or return ();
    return ($w,\@rest);
}

sub findrecord {
    my $fh = shift or return undef;
    my $w = shift;
    return undef unless defined($w);

    look($fh,$w,0,0);
    my ($n,$rest) = readrecord($fh) or return undef;
#    warn "findrecord: looking for \"$w\", found \"$n\"\n" if ($debug);
    return ($n eq $w) ? $rest : undef;
}
    
sub readsyns {
    my $file = shift;
    return () unless (-f $file);
    open(my $fh, $file) or return ();
    my %groupnums = ();
    my @syngroups = ();
    my $groupno = 1;
    my %currgroup = ();

    while (my $word = <$fh>) {
	next if ($word =~ /^\s*\#/); # skip comment lines
	$word =~ s/^\s+|\s+$//g;     # kill newline, leading blanks
	$word =~ tr/a-z/A-Z/;        # convert everything to upper case
	if ($word) {
	    # add to current group of synonyms
	    if ($groupnums{$word}) {
		warn "$script: warning: word \"$word\" already in syn group ",
		$groupnums{$word}, " ignoring second entry\n";
	    } else {
		$groupnums{$word} = $groupno;
		$currgroup{$word}++;
	    }
	} else { 
	    # it's a new group of synonyms, bump group number
	    if (%currgroup) {
		$syngroups[$groupno] = [ sort keys %currgroup ];
		%currgroup = ();
		$groupno++;
	    }
	}
    }
    
    # add last one...
    $syngroups[$groupno] = [ sort keys %currgroup ] if %currgroup;
    
    return ($groupno,\%groupnums,\@syngroups);
}
