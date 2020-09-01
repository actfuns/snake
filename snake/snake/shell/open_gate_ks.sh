#!/bin/bash

OP=$1
FLAG=$2

if [ ! $FLAG ] ; then
    FLAG=undefine_ks
fi

if [ ! $OP ] ; then
    OP=3
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'open gate ks '$OP
    echo 'open_gate '$OP | nc 127.0.0.1 20012
fi

