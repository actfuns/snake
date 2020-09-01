#!/bin/bash

FLAG=$1
if [ -z $FLAG ] ; then
    FLAG=undefine_bs
fi

ps aux|grep 'skynet' | grep $FLAG |grep -v 'grep' 1>/dev/null
if [ $? -eq 0 ] ; then
    echo 'exsit process skynet, skip start!'
    exit 2
fi

LOG_BAK_ROUT="bak"
if [ -f ./log/bs.log ]; then
    echo 'backup log'
    if [ ! -d ./log/$LOG_BAK_ROUT ]; then
        mkdir ./log/$LOG_BAK_ROUT
    fi
    dict=`pwd`
    cd ./log/$LOG_BAK_ROUT
    ls -t | awk '{if(NR>=10){print $0}}' | xargs rm -f
    cd $dict
    mv ./log/bs.log ./log/$LOG_BAK_ROUT/bs_`date +%Y%m%d-%H%M%S`.log
fi

echo 'checking local'
./shell/check_lua.sh

echo 'starting server'
nohup ./build/skynet ./config/bs_config.lua $FLAG > log/bs.out 2>&1 &
