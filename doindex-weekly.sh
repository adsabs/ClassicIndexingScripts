#!/bin/sh

script=`basename $0`
# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

[ "x$ADS_ENVIRONMENT" = "x" ] && eval `$HOME/.adsrc sh`
indexer="$ADS_INDEX_SERVER"

db="$1"
[ "x$db" = "x" ] && die "usage: $script DB"

master="$ADS_ABSTRACTS/$db/update/master.list"
[ -f $master ] || die "master list $master not found"

[ "$indexer" = `uname -n` ] || die "please run on $indexer"

logfile="$ADS_ABSTRACTS/$db/index/LOGS/"`date '+%F'`".log"

cd "$ADS_ABSTRACTS/$db/index"

echo $script started at `date`

/proj/ads/soft/abs/absload/index/dev/doindex $db $master > $logfile 2>&1 || \
    die "error running index for $db"

# As of March 2018, doindex makes things operational already
#/proj/ads/soft/abs/absload/index/dev/mkop.sh $db || \
#    die "error running mkop $db"

echo $script ended at `date`
