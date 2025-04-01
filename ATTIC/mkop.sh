#!/bin/sh
#
# Makes index operational on all local ADS abstract servers
#

script=`basename $0`

usage () {
    [ "x$1" = "x" ] || echo "$script: $1" 1>&2
    cat 1>&2 <<EOF
Usage: $script [--no-load] DB [version]
This script makes operational an index for database DB on the abstract
server hosts $ADS_ABSTRACT_SERVERS
If no version is specified, then "latest" is assumed.
EOF
     exit 1
}
dir=`dirname $0`
exe="$dir/mkop-host.sh"
hostname=`hostname`

for server in $ADS_ABSTRACT_SERVERS ; do
    if [ "$server" = "$hostname" ] ; then
		    echo "$script: executing command on $server"
		    $exe "$@"
		else 
        echo "$script: logging into $server..."
        ssh -t -t $server $exe "$@"
    fi
done

