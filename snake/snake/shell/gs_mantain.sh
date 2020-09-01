#!/bin/bash

NOTIFY=$1
FLAG=$2
if [ -z $FLAG ] ; then
    FLAG=undefine_gs
fi
if [ -z $NOTIFY ] ; then
    NOTIFY=notify
fi

./shell/gs_close.sh $NOTIFY $FLAG

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'there is some one forbid close gs'
else
    ./shell/gs_run.sh $FLAG

    sleep 12
    ./shell/open_gate.sh 3 $FLAG
fi

