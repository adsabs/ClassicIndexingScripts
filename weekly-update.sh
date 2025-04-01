#!/bin/sh
#
# Runs a number of updates during the weekend (typically starting early
# saturday morning) that either do full index updates or just the 
# abstract codes (properties) and index.status file.  Best run from
# a cron job.
#
# AA 1/25/13

script=`basename $0`
# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

msg () {
    echo "$script: $@ at "`date` 1>&2
}

olderthan () {
    f="$1"; shift
    d="$1"; shift
    ts=`perl -e 'print int(-M $ARGV[0])' $f`
    [ $ts -ge $d ] && return 0
    return 1
}

[ "x$ADS_ENVIRONMENT" = "x" ] && eval `$HOME/.adsrc sh`
indexer="$ADS_INDEX_SERVER"
[ "$indexer" = `uname -n` ] || die "please run on $indexer"
PATH=/proj/ads/soft/abs/absload/index/dev:$PATH
export PATH

# first reindex astro and pre databases
for db in "pre" "ast"; do
    msg "reindexing $db database"
    doindex-weekly.sh $db || die "indexing $db"
done

# recreate all codes
codeslog="$ADS_TMP/mkcodes.log"
msg "recreating all codes, log file is $codeslog"
mkcodes.sh --all --changebibs 2>&1 > $codeslog || \
    die "recreating codes, see $codeslog"

# now update timestamp file if older than X days
days=4
for db in "phy" "gen" ; do
    loaddir="$ADS_ABSTRACTS/$db/load/current"
    timestampf="$loaddir/index.status"
    tmpf="$ADS_TMP/index.status.$$"
    if olderthan $timestampf $days ; then
	msg "file $timestampf is olderthan $days days, recreating it"
	bibsignature $db > "$tmpf" || \
	    die "creating file $tmpf"
	sort -T $ADS_TMP -fuo "$tmpf" "$tmpf" || \
	    die "sorting file $tmpf"
	mv -fv "$tmpf" "$timestampf" || \
	    die "moving $tmpf to $timestampf"
    else
	msg "$file $timestampf is not yet $days days old"
    fi
done

# now push the update to ADS 2.0
msg "now pushing update to ADS 2.0"
/proj/ads/soft/bin/update_ads2.sh || \
    msg "warning: something may have gone wrong with ADS 2.0 update"

# no need to mirror since the arXiv update takes care of that
#mirrorlog="$ADS_TMP/mirror.log"
#msg "mirroring codes"
#/proj/ads/ads/mirror/local/bin/mirror sites=ALL dbs=ALL update=codes mkop=codes || \
#    die "mirroring codes, see $mirrorlog"

msg "ending script"
