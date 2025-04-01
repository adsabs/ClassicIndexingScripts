#!/bin/sh
#
# $Id: doindex.sh,v 1.4 2007/03/12 20:33:22 ads Exp ads $
#
# $Log: doindex.sh,v $
# Revision 1.4  2007/03/12 20:33:22  ads
# Added creation of TIMESTAMP.{start,end}update
#
# Revision 1.3  2006/12/19 18:42:04  ads
# Creation of bibcodes.list.alt and bibcodes.list.del is now
# handled by mkdeletedbibs.pl
#
# Revision 1.2  2006/09/11 15:58:07  ads
# Added caching of author.syn.auto so that on incremental
# indexing these don't get lost.
#
# Revision 1.1  2003/11/17 15:57:14  ads
# Initial revision
#
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

date=`date +'%Y-%m-%d'`
time=`date +'%H:%M:%S'`

usage () {
    echo "$script: $1" 
    cat <<EOF
Usage: $script [OPTIONS] db [master [load [topdir]]]
  db:      database to index; one of $ADS_DATABASES
  master:  the input master list file
           (default: topdir/update/master.list)
  load:    the directory where index files are to be deposited
           (default: topdir/load/$date)
  topdir:  top-level directory under which text files can be found
           (default: $ADS_ABSTRACTS/db)
OPTIONS:
  --bytes        use bytes rather than 32-bit integers as index offsets, counts
  --force-cache  force the use of the previous index cache
  --no-cache     disable the use of the previous index cache
  --dryrun       check for inconsistencies in master list and quit

Example:
  $script pre ./master.list /proj/adswon/abstracts/pre/test /proj/adswon/abstracts/pre
EOF
    exit 1
}
dir=`dirname $0`
export PATH="$dir:$PATH"

# LC_ALL should already be set to C, but just in case...
export LC_ALL="C"
export TMPDIR="$ADS_TMP"

# this is the variable that controls whether the cache is used
usecache=

# these are the fields that we are indexing
#fields="author affiliation object object_LPI object_IAU keyword pacs pacskwds title text"
fields="author object object_LPI object_IAU keyword pacs pacskwds title text"

# use bytes rather than offsets in indices?
bytes=

while [ $# -ne 0 ] ; do
    case "$1" in
	--no-cache) 
	    usecache='NO' ;;
	--force-cache) 
	    usecache='YES' ;;
	--bytes) 
	    bytes='--bytes';;
	--dryrun) 
	    dryrun='YES' ;;
        --help)
	    usage ;;
	-*)
	    die "unknown option $1" ;;
	*)
	    break ;;
    esac
    shift
done
[ \( $# -lt 1 \) -o \( $# -gt 4 \) ] && \
    usage "incorrect number of arguments supplied"

db=`echo "$1" | tr '[A-Z]' '[a-z]'`
topdir=${4-$ADS_ABSTRACTS/$db}
master=${2-$topdir/update/master.list}
loaddir=${3-$topdir/load/$date}

indexdir="$topdir/index/active.$date"
lastindex="$topdir/index/current"
lastload="$topdir/load/current"

[ -f "$master" ] || die "input master list file $master not found!"

if [ ! -d "$loaddir" ] ; then
    [ "x$dryrun" = "xYES" ] || \
	mkdir -p $loaddir || die "error creating directory $loaddir"
fi

[ -d "$topdir" ] || die "directory $topdir does not exist!"
[ -d "$indexdir" ] && die "directory $indexdir exists already!"
if [ ! -d "$lastindex" ] ; then
    warn "no active index directory found, disabling cache"
    usecache='NO'
fi
warn "indexing started"

# generate list of directories for text mirroring
(cd "$topdir/text" && /bin/ls -1d [A-Z][0-9][0-9] > dirs.list)

mkdir -p $indexdir || die "cannot create $indexdir"
mkdir "$indexdir/config" || die "cannot create $indexdir/config"

if [ "x$usecache" = "xYES" ] ; then
    # force the use of old cache
    warn "forcing the re-use of cache from $lastindex"
    rsync -a "$lastindex/config/." "$indexdir/config/." || \
	die "error syncing $lastindex/config to $indexdir/config"
else 
    # XXX: sourcedir is used to fetch a specific version of the text parser
    #	--sourcedir $dir \
    setup_index_config.pl --targetdir "$indexdir/config" \
	--db $db $fields || \
	die "error setting up index config"
    setup_author_syns.pl "$indexdir/config/author.syn" || \
	die "error setting up author synonyms"
fi

# first copy the master list to the indexing directory
orig_dir=`pwd`
orig_master="$master"
cp -pv $master "$indexdir/master.list" || \
    die "error copying $master to $indexdir/master.list"
cd $indexdir || die "cannot cd to $indexdir"
master="master.list"
date '+%Y-%m-%d %H:%M:%S' > "TIMESTAMP.start"
date '+%m%d' > VERSION

# update master list with current entry date
warn "updating entry dates in master list with current date"
perl -MPOSIX -pi -e '
    BEGIN { $ed = POSIX::strftime("%y%m%d",localtime(time)) }
    my (@F) = split; next unless @F; $F[-1] = $ed unless($F[-1] > 0);
    $_ = join("\t",@F) . "\n";
' $master || die "cannot update entry date in master list $master"

# copy back the new master list
if [ "x$dryrun" != "xYES" ] ; then
    cd $orig_dir
    cp "$indexdir/$master" $orig_master || \
		    die "cannot copy $master to $orig_master"
    cd $indexdir
fi

warn "input file is a master list"
makebib.pl --topdir "$topdir/text" $master > accnos.input || \
    die "cannot run makebib.pl"
sort -fo accnos.input accnos.input || \
    die "cannot sort accnos.input"
gzip -vf $master || die "cannot compress file $master"

[ "x$dryrun" = "xYES" ] && warn "dry run: exiting" && exit 0


# check cache and establish if it is still valid
if [ "x$usecache" != "xNO" ] ; then
    # now setup cache
    if setup_index_cache.pl $lastindex $indexdir ; then
	usecache="YES"
    else
	usecache="NO"
    fi
fi

if [ "x$usecache" = "xYES" ] ; then
    # see if cache exists, and if so use it
    if [ -s accnos.input.cache ] ; then
	sort -fo accnos.input.cache accnos.input.cache || \
	    die "cannot sort file accnos.cache"
	for file in $lastindex/*.parsed $lastindex/*_codes.accnos \
	    $lastindex/*.parsed.gz $lastindex/*_codes.accnos.gz ; do
	    [ -f $file ] || continue
	    source=`echo $file | sed -e 's/\.gz$//'`
	    target=`basename $source`
	    if [ "$file" = "$source" ] ; then
		# file is not compressed
		cat $file
	    else 
		# file is compressed 
		zcat $file
	    fi | \
		sort -f | join -i -t"	" accnos.input.cache - > $target || \
		die "cannot join accnos.input.cache and $file in $target"
	done
    fi
    # copy entries from the automatically generated author synonyms
    if [ -f "$lastindex/author.syn.auto" ] ; then
	cp -pv "$lastindex/author.syn.auto" . || \
	    warn "cannot copy $lastindex/author.syn.auto to current dir"
    fi
else
    touch accnos.input.cache || \
	die "cannot create file accnos.cache"
    cp accnos.input accnos.input.todo || \
	die "cannot copy accnos.input to accnos.todo"
fi

# now parse input files
if [ -s accnos.input.todo ] ; then
    warn "indexing "`wc -l < accnos.input.todo`" new or updated records"
    tokenizer.pl --configdir ./config $fields \
	< accnos.input.todo > accnos.done || \
	die "error running tokenizer.pl"
    # add the entries from the cached files to the list of accnos done
    join -i -t "	" accnos.input accnos.input.cache >> accnos.done || \
	die "cannot add cached accnos to accnos.done"
    sort -fuo accnos.done accnos.done || \
	die "cannot sort accnos.done"
    [ -f text.parsed.raw ] && \
	jointextlines.pl < text.parsed.raw >> text.parsed || \
	    die "error joining lines of file text.parsed.raw"
    [ -f title.parsed.raw ] && \
	jointextlines.pl < title.parsed.raw >> title.parsed || \
	    die "error joining lines of file title.parsed.raw"
else 
    warn "no new files to be parsed"
    cp accnos.input accnos.done || \
	die "cannot rename accnos.cache to accnos.done"
fi

for file in *.parsed ; do
    [ -f $file ] || continue
    sort -fo $file $file || die "error sorting file $file"
    if [ ! -s $file ] ; then
	warn "removing empty file $file"
	/bin/rm $file
    fi
done

sort -fuo bib2accno.list bib2accno.list || \
    die "cannot sort bib2accno.list"
sort -fuo master.bib master.bib || \
    die "cannot sort master.bib"

if [ -f "$topdir/update/bibcodes.deleted" ] ; then
    mkdeletedbibs.pl bib2accno.list < "$topdir/update/bibcodes.deleted" > \
	bibcodes.list.del || die "cannot create deleted bibcode list"
    sort -fuo bibcodes.list.del bibcodes.list.del
fi

# this is only used for preprint updates: alternate
# bibcodes are kept in a separate file rather than 
# the original master list
if [ -f "$topdir/update/bibcodes.alternate" ] ; then
    mkdeletedbibs.pl --alternates bib2accno.list \
	< "$topdir/update/bibcodes.alternate" \
	> bibcodes.list.alt || die "cannot create alternate bibcode list"
    sort -fuo bibcodes.list.alt bibcodes.list.alt
fi

# total number of documents
ntot=`wc -l < bib2accno.list`

# now create words files
cut -f2 bib2accno.list | parsed2words.pl *.parsed || \
    die "error running parsed2words"

# create *_codes files out of *_codes.accnos files
accno2codes.pl *_codes.accnos < bib2accno.list || \
    die "error running accno2codes.pl"

# create list of normalized authors and keywords
norm_authors.pl < author.words | id2bib bib2accno.list > norm_authors.bib || \
    warn "cannot create file norm_authors.bib"

if [ "x$db" = "xast" ] ; then
    # normalize keywords
    /proj/ads/soft/articles/bin/kwnormalizer < keyword.words > \
	norm_keywords.words || \
	warn "error creating normalized keyword file norm_keywords.words"
elif [ "x$db" = "xphy" ] ; then
    perl -pe 's/\s*\;\s*/\t/g' pacskwds.words > norm_keywords.words || \
	warn "error creating norm_keywords.words from pacskwds.words"
fi

# merge normalized keywords in file and create bibcode-norm keyword mapping
if [ -s norm_keywords.words ] ; then 
    /usr/bin/tr '[a-z]' '[A-Z]' < norm_keywords.words | \
	sort -T . -n keyword.words - > keyword.words.tmp || \
	warn "error sorting keyword.words and norm_keywords.words"
    /bin/mv -f keyword.words.tmp keyword.words
    id2bib bib2accno.list < norm_keywords.words > norm_keywords.bib || \
	warn "error creating file norm_keywords.bib"
    /bin/rm norm_keywords.words || \
	warn "error removing file norm_keywords.words"
else
    /bin/touch norm_keywords.bib
fi
if [ -s pacs.words ] ; then
    id2bib bib2accno.list < pacs.words > pacs.bib || \
	warn "error creating file pacs.bib"
    /bin/rm pacs.words || \
	warn "error removing pacs.words"
else
    /bin/touch pacs.bib
fi

# this is used to create word clouds
id2bib --uniq bib2accno.list < text.words > text.bib || \
    warn "error creating text.bib"

# create regular index files
for file in *.words ; do
    mkindex $file || \
	die "error inverting file $file"
done

# deal with synonyms
cp -pv ./config/*.syn . || die "copying synonym files"

# create full-author synonyms from original file
# XXX - 6/6/2011 AA 
# add astronomy author index to enable author name 
# synonym creation 
[ "x$db" = "xast" ] || xtra_authors="/proj/ads/abstracts/ast/load/current/author.index"
sort -fuo author.index author.index || die "error sorting author.index"
mkfullsynonyms.pl author.syn author.index $xtra_authors > author.syn.full || \
    die "creating full-author synonyms"
[ -f author.syn.full ] || touch author.syn.full
[ -f author.syn.auto ] || touch author.syn.auto
merge_synonyms.pl author.syn.full author.syn.auto > author.syn || \
    die "creating author.syn from author.syn.full and author.syn.auto"
addsyns.pl *.index || die "adding synonyms"

# now do some special processing for text and author files
addstems.pl --configdir ./config title.index || \
    warn "error adding stems to title.index, continuing"
addstems.pl --configdir ./config text.index || \
    warn "error adding stems to text.index, continuing"

for file in *.index *_codes ; do
    [ -f $file ] || continue
    sort -fuo $file $file || die "cannot sort file $file"
done
addscore.pl $bytes --ntot $ntot *.index || \
    die "adding word scores to index files"

# now update frequency of title index with the frequency from text index
changefreq.sh title.index text.index || \
    die "changing frequency of title.index to text.index"

# create files containing first and last update date
lastupdate=`cut -f4 bib2accno.list | sort -unr | head -1`
date +'%Y-%m-%d' -d "$lastupdate" > TIMESTAMP.endupdate
if [ -d "$lastload" -a -f "$lastload/TIMESTAMP.endupdate" ]; then 
    priorupdate=`cat "$lastload/TIMESTAMP.endupdate" | sed -e 's/-//g'`
    priorupdate=`expr $priorupdate + 1`
    [ "$priorupdate" -gt 0 ] && \
	date +'%Y-%m-%d' -d "$priorupdate" > TIMESTAMP.startupdate
fi

# create word frequency file used for word cloud
mkwordfreq.pl $bytes --thresh 2 --ntot $ntot --strip text.syn text.index > text.freq || \
    die "error creating text.freq"
sort -fuo text.freq text.freq || \
    die "error sorting text.freq"
mkwordfreq.pl $bytes --thresh 2 --ntot $ntot --strip title.syn title.index > title.freq || \
    die "error creating title.freq"
sort -fuo title.freq title.freq || \
    die "error sorting title.freq"

addcount.sh *.index bib2accno.list bibcodes.list.alt bibcodes.list.del || \
    die "error adding counts to index files"
addcount.sh --lines *_codes || \
    die "error adding line count to codes files"

# create pair indexes
#mkpairindex --hash-size 41943040 text.words || \
#    die "creating text pair index"
mkpairindex-full --partial-index --progress text.words  || \
    die "creating text pair index"
# AA as of June 2019 we need 40M key entries in pair index
mkpairindex --hash-size 41943040  title.words || \
    die "creating title pair index"
warn "adding pair scores"
addpairscore $bytes --ntot $ntot text_pairs.index title_pairs.index || \
    die "adding score to text_pairs.index and title_pairs.index"

mksoundex.sh author.index || \
    die "creating author soundex file"

# timestamp
warn "creating index timestamp"
date '+%Y-%m-%d %H:%M:%S' > "TIMESTAMP.end"

warn "moving index files to directory load"
if [ -d $loaddir ] ; then
    warn "deleting existing load directory $loaddir"
    /bin/rm -rf $loaddir || die "cannot remove old directory $loaddir"
fi
mkdir -p $loaddir || die "cannot create directory $loaddir"
mv -v *.index *.list TIMESTAMP.* VERSION *_codes $loaddir || \
    die "cannot move index files to $loaddir"
cp -pv config/*.trans config/*.kill config/*.kill_sens $loaddir || \
    die "cannot copy kill files to $loaddir"
[ -f bibcodes.list.alt ] && mv -v bibcodes.list.alt $loaddir
[ -f bibcodes.list.del ] && mv -v bibcodes.list.del $loaddir
[ "$bytes" ] || echo 4 > "$loaddir/OFFSETS"

warn "compressing words and parsed files"
for file in *.words *.parsed *.sorted *.raw *.accnos ; do
    [ -f $file ] || continue
    gzip -v $file || die "cannot compress file $file"
done

# now make this the current index
cd "$topdir/index"
if [ -L current ] ; then
    /bin/rm current || die "cannot make index $indexdir current"
fi
if [ -d "done.$date" ] ; then
    warn "renaming directory $topdir/index/done.$date to done.$date.bck"
    if [ -d "done.$date.bck" ] ; then
	/bin/rm -rf "done.$date.bck" || \
	    die "cannot remove directory done.$date.bck"
    fi
    mv "done.$date" "done.$date.bck" || \
	die "cannot backup directory done.$date"
fi
mv `basename $indexdir` "done.$date" || \
    die "cannot rename index dir $indexdir to $done.date"
ln -s "done.$date" current 

# make the load directory the latest
cd $loaddir; cd ..;
shortname=`basename $loaddir`
if [ "$shortname" = "latest" ] ; then
    :
elif [ -L "latest" ] ; then
    /bin/rm -f "latest" || die "cannot remove symlink latest"
elif [ -d "latest" ] ; then
    warn "removing load directory latest"
    /bin/rm -rf latest || die "cannot remove directory latest"
fi

warn "resetting symbolic link latest for current load dir"
ln -s "$shortname" latest || \
    die "cannot link load dir $loaddir to latest"

# now create MD5SUM, avoiding *codes files since they get
# sometimes recreated after this is done
warn "creating MD5 checksums in $loaddir"
cd $loaddir
/bin/ls -1 | grep -v 'codes$' | xargs md5sum > .MD5SUM || \
    warn "could not generate .MD5SUM in $loaddir"
mv -f .MD5SUM MD5SUM

warn "index directory is $topdir/index/done.$date"
warn "load directory is $loaddir"
warn "index ended"
