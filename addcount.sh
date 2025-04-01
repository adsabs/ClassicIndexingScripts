#!/bin/sh

script=`basename $0`

# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}

warn () {
    echo "$script: $1" 1>&2
}

wcopts="-l -c"
if [ "x$1" = "x--lines" ] ; then
    shift; wcopts="-l"
fi

for f in "$@" ; do
    [ ! -f $f ] && continue
    if [ -s "$f" ] ; then 
	#warn "adding line count to file $f"
	echo -n " " > $f.tmp || exit 1
	cut -f1 $f | wc $wcopts >> $f.tmp || exit 2
	cat $f >> $f.tmp || exit 3
        mv -f $f.tmp $f || exit 4
    else 
        #warn "file $f has zero byte size, removing it"
        rm -f $f
    fi
done
