#!/bin/bash

rm -Rf check_daobiao_attr.out

Luas=`find ./luadata -name "*.lua"`
if [ "${Luas}" != "" ]; then
	for i in ${Luas}
	do
		./tools/lua/lua ./check_daobiao_attr.lua ${i} check_daobiao_attr.out
	done
fi
