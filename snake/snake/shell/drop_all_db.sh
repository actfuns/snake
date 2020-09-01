#!/bin/bash

ADDR=$1
FLAG=$2
if [ ! $FLAG ] ; then
    if [ ! $ADDR ] ; then
        ADDR="127.0.0.1:27017"
    elif [ $ADDR = "dropall" ] ; then
        ADDR="127.0.0.1:27017"
        FLAG="dropall"
    fi
fi

if [ ! $FLAG ] || [ $FLAG != "dropall" ] ; then
    echo "[警告]执行此指令将删除以下所有数据库,若确定执行,请执行./shell/drop_all_db.sh dropall"
    mongo $ADDR -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin --quiet --eval "load('./shell/dropdbs.js'); GetDropDBs();"
    exit
fi


mongo $ADDR -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin --quiet --eval "load('./shell/dropdbs.js'); DropDBs();"
