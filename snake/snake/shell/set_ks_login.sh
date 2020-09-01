#!/bin/bash

STATUS=$1
FLAG=$2

if [ -z $FLAG ] ; then
    FLAG=undefine_gs
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo "set ks login $STATUS"
    echo "set_ks_login $STATUS" | nc 127.0.0.1 7002
fi
