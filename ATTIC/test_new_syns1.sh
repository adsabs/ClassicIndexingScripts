#!/bin/sh

script=`basename $0`

# writes an error message and exits
die () {
    echo "$script: fatal error: $1 occurred at " `date` 1>&2
    exit 1
}


PATH=/proj/ads/soft/abs/absload/index/dev:$PATH
export PATH

load="/proj/ads/abstracts/ast/load/current"

ntot=`cat ../accnos.done | wc -l`
cp /proj/ads/abstracts/config/author.syn ./author.syn.orig || \
    die "cannot copy author.syn new to author.syn"
cp ../author.syn.auto . || \
    die "cannot copy ../author.syn.auto to ."
gunzip < ../author.words.gz > author.words || \
    die "cannot uncompress author.words"
mkindex author.words || \
    die "mkindex author.words"
sort -fuo author.index author.index || \
    die "sorting author.index"
mkfullsynonyms.pl author.syn.orig author.index > author.syn.full || \
    die "Creationg author.syn.full"

[ -f author.syn.full ] || touch author.syn.full
[ -f author.syn.auto ] || touch author.syn.auto
merge_synonyms.pl author.syn.orig author.syn.full author.syn.auto > author.syn || \
    die "creating author.syn from author.syn.full and author.syn.auto"

cp author.index author.index.nosyns || \
    die "copying author.index to author.index.nosyns"
addsyns.pl author.index || \
    die "adding synonyms"
sort -fuo author.index author.index || \
    die "sorting author.index"
addscore.pl --bytes --ntot $ntot  author.index || \
    die "adding word score to author.index"
addcount.sh author.index || \
    die "adding count to author.index"

compare_index.pl --bytes --full --idfile "$load/bib2accno.list" \
    author.index "$load/author.index" > author.diff
