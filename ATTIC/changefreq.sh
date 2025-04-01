#!/bin/sh
#
# $Id$
#
# Overrides score column in first index file with entries 
# from second index.  Used to force scores from text files
# into title index
#
# $Log$
#

script=`basename $0`

usage () {
    echo "Usage: $script destfile sourcefile" 1>&2
    exit 1
}
# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

[ $# = 2 ]  || usage
[ -f "$1" ] || die "file $1 not found"
[ -f "$2" ] || die "file $2 not found" 
join -t "	" -i -o 1.1,2.2,1.3,1.4,2.5,1.6,1.7,1.8 $1 $2 > $1.tmp || \
    die "cannot join file $1 and $2"
mv -f $1.tmp $1 || die "cannot move file $1.tmp to $1"
exit 0
