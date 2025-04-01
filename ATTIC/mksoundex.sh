#!/bin/sh
# 
# Creates author soundex file
#
p=`basename $0`
die () {
    echo "$p: fatal error: $@" 1>&2
    exit 1
}

# creates soundex file for author last names
[ -f $1 ] || die "no input file specified"

echo "$p: creating soundex terms for index file $1 on " `date`
perl -lne 'print if (s/,.*$// and $_)' $1 | sort -fu | soundex > $1.soundex || \
    die "cannot create file $1.soundex"
perl -lne 'print if (s/,.*$// and $_)' $1 | sort -fu | phonix  > $1.phonix  || \
    die "cannot create file $1.phonix"
sort $1.soundex $1.phonix | mkpart.pl > soundex.dat || \
    die "cannot create file soundex.dat"
mkbinindex.pl soundex.dat || \
    die "cannot create files soundex.index and soundex.list"
/bin/rm soundex.dat $1.soundex $1.phonix || \
    die "cannot remove files soundex.dat $1.soundex $1.phonix"

exit 0
