#!/bin/sh
#
# $Id$
#
# Usage: matchpp.sh db loaddir
#
# $Log$
#

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

join -i -v1 -t "	" "$loaddir/bib2accno.list" "$curload/bib2accno.list" | \
    tail -n +2 | perl -lane 'print "$F[0]\t$F[1]" if $F[2] > 199200' \
	> matches.input.tmp || die "error creating file matches.input"

[ -s matches.input.tmp ] || die "no new records to match"
mv matches.input.tmp matches.input || die "cannot move matches.input.tmp to matches.input"
# now generate list of metadata files to be used by python matcher

ilist=`pwd`"/match_oracle.input"
olist=`pwd`"/match_oracle.output"
cut -f2 matches.input | sort -f | join -i -t "	" - accnos.input | cut -f2 > $ilist || \
    die "cannot generate $ilist"
warn "submitting the list of "`wc -l < $ilist`" metadata records to docmatch scripts at "`date`
command="/usr/local/bin/rjob -j process python3 /app/match_to_arxiv.py -i $ilist -o $olist"
remote="adsnest docker exec -i -u ads backoffice_prod_doc_matching_pipeline_1 bash -l -s"
echo "$script: executing \"$command\" via: \"ssh $remote\""
echo "$command" | ssh $remote || \
    warn "error running script $remote"
echo "$script: matched "`wc -l < $olist`" records at "`date`


# first generate list of which bibcodes are refereed in input list
$ADS_ABSCONFIG/links/refereed/all.flt < matches.input | \
    sort -fuo refereed.dat || die "cannot generate list of refereed bibcodes"

warn "starting matching of "`wc -l < matches.input`" new records at "`date`

/proj/ads/abstracts/sources/ArXiv/bin/match.pl --exclude /dev/null \
    --refereed ./refereed.dat --db $db \
    < ./matches.input > ./matches.output 2> ./matches.log || \
	die "error running match.pl"

warn "matched a total of "`wc -l < matches.output`" records at "`date`

cat matches.output >> $ADS_ABSTRACTS/sources/ArXiv/published/matches.list.pub2pre

###                                                                                                                                                                       
upload_olist="$olist.csv"
clist=`pwd`"/match_oracle_compare.csv"
classic_list=`pwd`"/matches.output"
echo "$script: comparing the list of "`wc -l < $upload_olist`" metadata records with classic "`date`
command="/usr/local/bin/rjob -j process python3 /app/compare_to_classic.py -c $classic_list -a $upload_olist -o $clist -s pub"
remote="adsnest docker exec -i -u ads backoffice_prod_doc_matching_pipeline_1 bash -l -s"
echo "$script: executing \"$command\" via: \"ssh $remote\""
echo "$command" | ssh $remote || \
    warn "error running script $remote"
echo "$script: output comparison of "`wc -l < $clist`" records found in file $clist at "`date`

echo "$script: uploading $upload_olist and $clist go google drive"
datestamp=`basename $loaddir`
#updated gdfolder to use ADS TeamDrive / ADSBotDocMatching, 2023Jan23 -MT
#gdfolder='1UcGIaI1SQnW3IQjF00Ydn9rtei95DfEL'
gdfolder='1Xhr9gV9iZ4IkbaXVdmo5ZrrkRZ1KUTtP'
#/proj/ads/abstracts/sources/ArXiv/bin/gdupload.sh -g sheets -m text/csv -p "$gdfolder" -n "$datestamp.pubmatch.csv" -f "$upload_olist"
/proj/ads/abstracts/sources/ArXiv/bin/gdupload.sh -g sheets -m text/csv -p "$gdfolder" -n "$datestamp.pubcompare.csv" -f "$clist"
echo "$script: spreadsheet uploaded to google drive: https://drive.google.com/drive/u/2/folders/$gdfolder"

