#!/bin/bash
if [ $# -lt 1 ] ; then
    echo "usage: mongobak <server_list or server_key>"
    exit 2
fi

./shell/master/distribute.py remote $1 ./shell/mongobak.sh