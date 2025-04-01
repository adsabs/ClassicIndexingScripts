#!/bin/sh
#
# Wrapper around doindex.sh to run mkcodes and mirroring after an index
#

script=`basename $0`
docodes=/bin/true
domirror=/bin/true
indexer="adsduo"

# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

warn () {
    echo "$script: $1 at " `date` 1>&2
}

while [ $# -ne 0 ] ; do
    case "$1" in
        --dryrun)
            dryrun="$1" ;;
        --no-codes)
            docodes=/bin/false ;;
        --no-mirror)
            domirror=/bin/false ;;
        --*)
	    opt="$opt $1";;
        *)
            break ;;
    esac
    shift
done

[ "$indexer" = `uname -n` ] || \
    die "this script needs to be run on host $indexer"

if [ $# -ne 2 ] ; then
    echo "Usage: $script [--no-cache] [--no-codes] [--no-mirror] [--dryrun] db date" 1>&2
    exit 1
fi


#date=`date +'%Y-%m-%d'`
db=`echo "$1" | tr '[A-Z]' '[a-z]'`
date="$2"
loaddir="/proj/ads/abstracts/$db/load/$date"
indexdir="/proj/ads/abstracts/$db/index/done.$date"

warn "this script was called as: $0 $@"

dir=`dirname $0`

#$dir/indexstatus "$loaddir" "$indexdir" > "$loaddir/index.status" || \
#    warn "error creating index status"
$dir/bibsignature "$loaddir" "$indexdir" > "$loaddir/index.status" || \
    warn "error creating index status"
sort -fuo "$loaddir/index.status" "$loaddir/index.status" || \
    warn "error sorting $loaddir/index.status"

$dir/matchpp.sh $db $loaddir || \
    warn "matchpp returned status of $?"

warn "Index is ready in directory $loaddir"

if $domirror ; then
    /proj/ads/ads/mirror/local/bin/mirror sites=ALL db="$db" \
        update=text update=latest batch=YES
fi

