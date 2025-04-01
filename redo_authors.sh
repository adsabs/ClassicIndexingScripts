#!/bin/sh
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
dir=`dirname $0`
export PATH="$dir:$PATH"

# LC_ALL should already be set to C, but just in case...
export LC_ALL="C"
export TMPDIR="$ADS_TMP"

[ $# -ne 1 ] && die "usage: $0 db"
db="$1"

indexdir="/proj/ads/abstracts/$db/index/current"
loaddir="/proj/ads/abstracts/$db/load/current"

[ -d $loaddir ] || die "cannot find $loaddir"
cd $indexdir || die "cannot cd to $indexdir"

cp -pv /proj/ads/abstracts/config/author.syn ./config

# now parse input files
tokenizer.pl --configdir ./config author < accnos.input > /dev/null
sort -fo author.parsed author.parsed
tail -n +2 "$loaddir/bib2accno.list" > bib2accno.list
ntot=`wc -l < bib2accno.list`
cut -f2 bib2accno.list | parsed2words.pl author.parsed || \
    die "error running parsed2words"
mkindex author.words

# create full-author synonyms from original file
sort -fuo author.index author.index || die "error sorting author.index"
mv config/author.syn config/author.syn.orig || die "moving author.syn"
mkfullsynonyms.pl config/author.syn.orig author.index > config/author.syn || \
    die "creating full-author synonyms"

# deal with synonyms
addsyns.pl --configdir ./config author.index || \
    die "adding synonyms"

sort -fuo author.index author.index || die "sorting author.index"

addscore.pl --bytes --ntot $ntot author.index || \
    die "adding word scores to index files"

addcount.sh author.index
mksoundex.sh author.index || \
    die "creating author soundex file"

# timestamp
warn "creating index timestamp"
date '+%Y-%m-%d %H:%M:%S' > "TIMESTAMP.end"
/bin/rm author.parsed author.words
gzip author.parsed author.words
/bin/rm *.parsed

mv $loaddir/author.index ./author.index.bck
mv $loaddir/author.list ./author.list.bck
mv $loaddir/soundex.index ./soundex.index.bck
mv $loaddir/soundex.list ./soundex.list.bck
rm $loaddir/TIMESTAMP.end

mv -vf TIMESTAMP.end author.index author.list soundex.index soundex.list $loaddir


