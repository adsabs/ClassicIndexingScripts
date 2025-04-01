#!/bin/sh

echo script is $0

if [ $0 = `basename $0` ] ; then
    echo directory is in path
else 
    dir=`dirname $0`
    echo adding $dir to path
fi
