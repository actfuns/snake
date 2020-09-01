#!/bin/bash
if [ "$#" -lt "1" ] ; then
    echo "usage: sync_code <server_key or server_list>"
    exit 2
fi
ISOPEN="true"
if [ -z $ISOPEN ]; then
    echo "invalid script"
    exit 2
fi

SERVER=$1

pack_name="code"
rm -Rf $pack_name
python ./shell/pack.py "./" $pack_name
if [ ! -f "version.out" ]; then
    touch $pack_name/version.out
    svn info > $pack_name/version.out
    echo "pack_code ${CURDIR} `date +%Y-%m-%d_%H-%M-%S`" >> $pack_name/version.out
else
    cp version.out $pack_name/version.out
fi

./shell/master/distribute.py local ${SERVER} ./shell/master/rsync_conf.sh ${pack_name}
echo "remote transfer finish"

rm -Rf $pack_name
echo "sync_code finish "${SERVER}
