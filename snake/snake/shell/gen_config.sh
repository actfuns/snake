#!/bin/bash

SERVER_KEY=$1
SERVER_IP=$2

if [ ! $SERVER_IP ] ; then
    SERVER_IP=$(LC_ALL=C ifconfig eth0 |grep "inet addr" | cut -f 2 -d ":"|cut -f 1 -d " ")
fi

python ./shell/generate_conf.py $SERVER_KEY $SERVER_IP