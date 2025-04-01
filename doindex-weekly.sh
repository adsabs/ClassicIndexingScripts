#!/bin/sh

script=`basename $0`
fullscript=`readlink -f $0`
dir=`dirname $fullscript`
# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

[ "x$ADS_ENVIRONMENT" = "x" ] && eval `$HOME/.adsrc sh`

db="$1"
[ "x$db" = "x" ] && die "usage: $script DB"

master="$ADS_ABSTRACTS/$db/update/master.list"
[ -f $master ] || die "master list $master not found"
logfile="$ADS_ABSTRACTS/$db/index/LOGS/"`date '+%F'`".log"
cd "$ADS_ABSTRACTS/$db/index"
echo $script started at `date`

$dir/doindex $db $master > $logfile 2>&1 || \
    die "error running index for $db"

echo $script ended at `date`
