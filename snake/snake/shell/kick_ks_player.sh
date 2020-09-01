#!/bin/bash

SERVER=$1
FLAG=$2

if [ -z $FLAG ] ; then
    FLAG=undefine_gs
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo "kick ks player $SERVER"
    echo "kick_ks_player $SERVER" | nc 127.0.0.1 20012
fi
