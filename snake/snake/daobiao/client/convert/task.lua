module(..., package.seeall)
function main()
	local newTable = {}

	-- 任务类型
	local taskType = require("task.tasktype")
	-- 任务物品
	local taskItem = require("task.taskitem")
	-- 任务采集
	local taskPick = require("task.taskpick")

	local taskAssist = require("task.taskassist")

	local d1 = require("task.story.taskhead")
	local d2 = require("task.everydaytask")
	local d3 = require("task.story.story_chapter")
	local d4 = require("task.xuanshang.xuanshang_limit")

	local taskName = {"test", "story", "shimen", "ghost", "side", "yibao", "fuben", "schoolpass", "orgtask", 
	"lingxi", "guessgame", "jyfuben", "lead", "baotu", "runring", "xuanshang", "zhenmo", "imperialexam", "treasureconvoy"}
	for _,v in ipairs(taskName) do
		local taskMain = {}
		local task = {}
		local npc = {}
		-- 任务主体
		local oriTask = require("task." .. v .. ".task")
		for k, v in pairs(oriTask) do
			task[k] = {
				type = v.type,
				tasktype = v.tasktype,
				tips = v.tips,
				submitNpcId = v.submitNpcId,
				clientExtStr = v.clientExtStr,
				submitRewardStr = v.submitRewardStr,
				name = v.name,
				acceptNpcId = v.acceptNpcId,
				description = v.description,
				linkid = v.linkid,
				trigger_flower_grow_radius = v.trigger_flower_grow_radius,
				goalDesc = v.goalDesc,
				chapter_progress = v.chapter_progress,
				chapter_mark = v.chapter_mark,
				bossDesc = v.bossDesc,
				prereward = v.prereward,
			}
		end
		taskMain.TASK = task

		-- 任务Npc
		local oriNpc = require("npc.task_" .. v .. "_npc")
		for k, v in pairs(oriNpc) do
			npc[k] = {
				name = v.name,
				figureid = v.figureid,
				rotateY = v.rotateY,
				dialogStrList = v.dialogStrList,
				dialogtime = v.dialogtime,
			}
		end
		taskMain.NPC = npc

		-- 装箱
		newTable[string.upper(v)] = taskMain
	end

	local s = table.dump(taskType, "TASKTYPE") .. "\n" .. table.dump(taskItem, "TASKITEM") .. "\n" .. table.dump(taskPick, "TASKPICK") .. "\n" .. table.dump(newTable, "TASK")
	.. "\n" .. table.dump(d1, "TASKCHAPTER") .. "\n" .. table.dump(d2, "EVERYDAYTASK") .. "\n" .. table.dump(d3, "STORYCHAPTER") .. "\n" .. table.dump(d4, "XUANSHANGCONFIG")
	.. "\n" .. table.dump(taskAssist, "TASKASSIST") 
	SaveToFile("task", s)
end
