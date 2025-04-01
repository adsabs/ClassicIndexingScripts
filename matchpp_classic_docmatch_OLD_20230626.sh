#!/bin/sh
#
# $Id$
#
# Usage: matchpp.sh db loaddir
#
# $Log$
#
# This script controls weekly matching of new content to existing eprints
# Revision: 2023 March 06 [MT]
#
# ===================================
#
# The new doc matching pipeline assumes there's a file called
# "match_oracle.input" in # .../[collection]/index/current
# The commands for generating the match_oracle.input file were removed some
# time since 2023 Jan, and this edit replaces them.  
# Last revision: 2023 May 05 [MT]

script=`basename $0`

# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

warn () {
    echo "$script: $1 at " `date` 1>&2
}

[ $# -gt 1 ] || die "Usage: $script db loaddir [olddir]"


# setting up needed variables for classic matching

db="$1"
loaddir="$2"
if [ "x$3" = "x" ] ; then
    curload=`dirname $loaddir`"/current"
else 
    curload="$3"
fi

curind="$ADS_ABSTRACTS/$db/index/current"

[ -d $loaddir ] || die "$loaddir is not a directory"
[ -d $curload ] || die "$curload is not a directory"
[ -d $curind  ] || die "$curind  is not a directory"

cd $curind || die "cannot cd to $curind"

if [ $db = "pre" ] ; then
    warn "skipping matching for preprint index"
    exit 0
fi

warn "previous load directory is $curload"
warn "latest   load directory is $loaddir"

# START classic matching process

join -i -v1 -t "	" "$loaddir/bib2accno.list" "$curload/bib2accno.list" | \
    tail -n +2 | perl -lane 'print "$F[0]\t$F[1]" if $F[2] > 199200' \
	> matches.input.tmp || die "error creating file matches.input"

[ -s matches.input.tmp ] || die "no new records to match"
mv matches.input.tmp matches.input || die "cannot move matches.input.tmp to matches.input"

# first generate list of which bibcodes are refereed in input list
$ADS_ABSCONFIG/links/refereed/all.flt < matches.input | \
    sort -fuo refereed.dat || die "cannot generate list of refereed bibcodes"

warn "starting matching of "`wc -l < matches.input`" new records at "`date`

/proj/ads/abstracts/sources/ArXiv/bin/match.pl --exclude /dev/null \
    --refereed ./refereed.dat --db $db \
    < ./matches.input > ./match.out 2> ./matches.log || \
	die "error running match.pl"

warn "matched a total of "`wc -l < match.out`" records at "`date`

cat match.out >> $ADS_ABSTRACTS/sources/ArXiv/published/matches.list.pub2pre

# END classic matching process


# START new docmatch process

ilist=`pwd`"/match_oracle.input"
olist=`pwd`"/matched_pub.output.csv"
cut -f2 matches.input | sort -f | join -i -t "	" - accnos.input | cut -f2 > $ilist || \
    die "cannot generate $ilist"
warn "submitting the list of "`wc -l < $ilist`" metadata records to docmatch scripts at "`date`


command="/usr/local/bin/rjob -j process python3 /app/run.py -me -p"`pwd`"/"

remote="adsnest docker exec -i -u ads backoffice_prod_doc_matching_pipeline_1 bash -l -s"

echo "$script: executing \"$command\" via: \"ssh $remote\""
echo "$command" | ssh $remote || \
    warn "error running script $remote"
echo "$script: matched "`wc -l < $olist`" records at "`date`

