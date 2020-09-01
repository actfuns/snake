#!/bin/bash
if [ $# -lt 1 ] ; then
    echo "usage: mongobak <server_type>"
    exit 2
fi

SERVER_TYPE=$1

if [ ${SERVER_TYPE} == "gs" ] ; then
    ./shell/mongobak_gs.sh
elif [ ${SERVER_TYPE} == "cs" ] ; then
    ./shell/mongobak_cs.sh
fi
