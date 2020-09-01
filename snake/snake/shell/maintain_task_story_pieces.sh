#!/bin/bash

# 维护任务主线剧情碎片，补发已经跳过的任务对应的碎片
# PS. 此版本针对碎片设定的记录（改为进度记录后不用）

while [ $# -gt 0 ]; do
	case $1 in
		-h)
			echo "sh 本脚本 [OPTIONS] [<拓扑用gamedata路径>]"
			echo "OPTIONS:"
			echo " -h           帮助"
			echo " -n           不拓扑，直接使用现有json"
			exit 0
			;;
		-n)
			# shift
			NO_TOPO=true
			shift
			# echo no topology, direct read json
			echo 无拓扑，直接读取json文件
			;;
		*)
			break
			;;
	esac
done
GAMEDATA_PATH=$1

if [ ! $NO_TOPO ]; then
	lua ./shell/maintain/task_story_pieces_topology.lua $GAMEDATA_PATH
	if [ $? -ne 0 ] ; then
		echo "拓扑失败"
		exit 1
	fi
	# echo "topology done, go on change db? [y/n]"
	echo "拓扑完成, 继续改写db? [y/n]"
	read go_on
	if [ "$go_on" != "y" ]; then
		# echo "abort db change, end"
		echo "放弃db操作"
		exit 0
	fi
fi
python shell/maintain/task_ensure_story_pieces.py
if [ $? -eq 0 ] ; then
	# echo "deal all"
	echo "db操作完成"
else
	# echo "deal fail"
	echo "db操作失败"
fi
