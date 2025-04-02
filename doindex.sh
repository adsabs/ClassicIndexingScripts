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
fullscript=`readlink -f $0`
dir=`dirname $fullscript`
export PATH="$dir:$PATH"

# LC_ALL should already be set to C, but just in case...
export LC_ALL="C"
export TMPDIR="$ADS_TMP"

# this is the variable that controls whether the cache is used
usecache=YES

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

mkdir -p $indexdir || die "cannot create $indexdir"
mkdir "$indexdir/config" || die "cannot create $indexdir/config"

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

# create files containing first and last update date
lastupdate=`cut -f4 bib2accno.list | sort -unr | head -1`
date +'%Y-%m-%d' -d "$lastupdate" > TIMESTAMP.endupdate
if [ -d "$lastload" -a -f "$lastload/TIMESTAMP.endupdate" ]; then 
    priorupdate=`cat "$lastload/TIMESTAMP.endupdate" | sed -e 's/-//g'`
    priorupdate=`expr $priorupdate + 1`
    [ "$priorupdate" -gt 0 ] && \
	date +'%Y-%m-%d' -d "$priorupdate" > TIMESTAMP.startupdate
fi

addcount.sh bib2accno.list bibcodes.list.alt bibcodes.list.del || \
    die "error adding counts to index files"

# timestamp
warn "creating index timestamp"
date '+%Y-%m-%d %H:%M:%S' > "TIMESTAMP.end"

warn "moving index files to directory load"
if [ -d $loaddir ] ; then
    warn "deleting existing load directory $loaddir"
    /bin/rm -rf $loaddir || die "cannot remove old directory $loaddir"
fi
mkdir -p $loaddir || die "cannot create directory $loaddir"
mv -v TIMESTAMP.* VERSION $loaddir || \
    die "cannot move index files to $loaddir"
[ -f bib2accno.list ] && mv -v bib2accno.list $loaddir
[ -f bibcodes.list.alt ] && mv -v bibcodes.list.alt $loaddir
[ -f bibcodes.list.del ] && mv -v bibcodes.list.del $loaddir

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

warn "index directory is $topdir/index/done.$date"
warn "load directory is $loaddir"
warn "index ended"
