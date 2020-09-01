#!/bin/bash

if [ `whoami` == "hellowork" ];then
    ./shell/gs_close.sh

    ./shell/date.sh "$1"

    sleep 12
    ./shell/gs_start.sh
fi