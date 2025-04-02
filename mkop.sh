#!/bin/sh
#
#
script=`basename $0`

usage () {
    [ "x$1" = "x" ] || echo "$script: $1" 1>&2
    cat 1>&2 <<EOF
Usage: $script [--no-load] DB [version]
This script makes operational an index for database DB on the current host.
If no version is specified, then "latest" is assumed.
EOF
     exit 1
}

die () {
    echo "$script: fatal error: $1" 1>&2
    exit 1
}

get_dir () {
     [ "x$1" = "x" ] && return 1
     [ -d "$1" ] || return 2
     cd $1 || return 3
     /bin/pwd | xargs basename
}

host=`uname -n`

load="YES"
while [ $# -ne 0 ] ; do
    case "$1" in
        --no-load)
            load='' ;;
        -*)
            usage "unknown option $1" ;;
        *)
            break ;;
    esac
    shift
done

db=`echo "$1" | tr '[A-Z]' '[a-z]'`
[ "x$db" = "x" ] && usage

current="$ADS_ABSTRACTS/$db/load/current"
[ -d "$current" ] || die "directory $current does not exist!"
version=${2-latest}
basedir=`dirname $current`
cd $basedir || die "cannot cd to base directory $basedir"
current=`basename $current`
versdir=`basename $version`
[ -d $versdir ] || \
    die "version directory $versdir does not exist in $basedir"

realdir=`get_dir $versdir` || \
    die "cannot get target directory for $versdir in $basedir"
realcur=`get_dir $current` || \
    die "cannot get target directory for $current in $basedir"

if [ "$realcur" = "$realdir" ] ; then
    echo "$script: directory $realdir is already operational"
else
    if /usr/bin/test -L $current ; then
	/bin/rm -f $current || \
	    die "cannot remove symbolic link $current in $basedir"
    else
	if [ -d "$current.old" ] ; then
	    /bin/rm -rf "$current.old" || \
		die "cannot remove directory $current.old in $basedir"
	fi
	mv "$current" "$current.old" || \
	    die "cannot move $current to $current.old in $basedir"
    fi
    ln -s $realdir $current || \
	die "cannot create link $current -> $realdir in $basedir"
fi

[ "x$load" = "x" ] && exit 0

