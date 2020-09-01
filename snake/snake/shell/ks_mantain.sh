#!/bin/bash

NOTIFY=$1
FLAG=$2
if [ -z $FLAG ] ; then
    FLAG=undefine_ks
fi
if [ -z $NOTIFY ] ; then
    NOTIFY=notify
fi

./shell/ks_close.sh $NOTIFY $FLAG

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'there is some one forbid close ks'
else
    ./shell/ks_run.sh $FLAG

    sleep 12
    ./shell/open_gate_ks.sh 3 $FLAG
fi

