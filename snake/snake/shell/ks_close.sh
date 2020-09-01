#!/bin/bash

NOTIFY=$1
FLAG=$2

if [ -z $FLAG ] ; then
    FLAG=undefine_ks
fi
if [ -z $NOTIFY ] ; then
    NOTIFY=notify
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'closing ks'
    echo "close_ks $NOTIFY" | nc 127.0.0.1 20012
    if [ $NOTIFY = 'notify' ]; then
        sleep 30
    else
        sleep 12
    fi
fi
