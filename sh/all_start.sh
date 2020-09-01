#!/bin/bash

FLAG=$1
BFLAG=$FLAG"_bs"
CFLAG=$FLAG"_cs"
GFLAG=$FLAG"_gs"
if [ -z $FLAG ] ; then
    BFLAG=undefine_bs
    CFLAG=undefine_cs
    GFLAG=undefine_gs
fi
./bs_kill.sh $BFLAG
./bs_run.sh $BFLAG
sleep 6
./cs_kill.sh $CFLAG
./cs_run.sh $CFLAG
sleep 6
./gs_kill.sh $GFLAG
./gs_run.sh $GFLAG
sleep 12
./open_gate.sh 3 $GFLAG