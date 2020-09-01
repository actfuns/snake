#!/bin/bash

NOTIFY=$1
FLAG=$2

if [ -z $FLAG ] ; then
    FLAG=undefine_gs
fi
if [ -z $NOTIFY ] ; then
    NOTIFY=notify
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'closing gs'
    echo "close_gs $NOTIFY" | nc 127.0.0.1 7002
    if [ $NOTIFY = 'notify' ]; then
        sleep 30
    else
        sleep 12
    fi
fi
