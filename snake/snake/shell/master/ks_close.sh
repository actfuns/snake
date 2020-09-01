#!/bin/bash
if [ $# -lt 1 ] ; then
    echo "usage: ks_close <server_list or server_key> [notify] [flag]"
    exit 2
fi

./shell/master/distribute.py remote $1 ./shell/ks_close.sh "${@:2}"
