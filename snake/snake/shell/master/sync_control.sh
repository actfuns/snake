#!/bin/bash

if [ $# -lt 1 ] ; then
    echo "usage: sync_control <flag>"
    exit 2
fi

FLAG=$1
if [ $FLAG == "pro" ]; then
    MONITORIP="47.100.116.107"
elif [ $FLAG == "dev" ]; then
    MONITORIP="120.132.14.47"
elif [ $FLAG == "h7d" ]; then
    MONITORIP="106.15.191.200"
else
    echo "invalid monitor ip"
    exit 3
fi

CURPATH=$(pwd)
CURDIR=${CURPATH##*/}

./shell/update.sh
make
echo "update and make finish "

pack_name="code"
rm -Rf $pack_name
python ./shell/pack.py "./" $pack_name
touch $pack_name/version.out
svn info > $pack_name/version.out
echo "pack_code ${CURDIR} `date +%Y-%m-%d_%H-%M-%S`" >> $pack_name/version.out

rsync -avzc --stats\
        --delete\
        --exclude 'log'\
        --exclude 'config/*.lua'\
        -e 'ssh -o ConnectTimeout=5 -p 932' $pack_name/ cilu@$MONITORIP:/home/cilu/$CURDIR
echo "remote transfer ${CURDIR} finish"

rm -Rf $pack_name
echo "sync_control finish "
