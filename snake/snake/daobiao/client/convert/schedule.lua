module(..., package.seeall)
function main()
	local schedule = require("schedule.schedule")
	local activereward = require("schedule.activereward")
	local week = require("schedule.week")
	local flowertype = require("huodong.shootcraps.flowertype")
    local luckyreward = require("huodong.shootcraps.luckreward")
    local hfdmskill = require("huodong.hfdm.skill")
    local d1 = require ("schedule.stopnotify")
    local d2 = require("schedule.text")
	local s = table.dump(schedule, "SCHEDULE") .. "\n" .. table.dump(activereward, "ACTIVEREWARD") .. "\n" .. table.dump(week, "WEEK").."\n" .. 
	table.dump(flowertype, "FLOWERTYPE").."\n" .. table.dump(luckyreward, "LUCKYREWARD").."\n" .. table.dump(hfdmskill, "HFDMSKILL").."\n" .. table.dump(d1, "STOPNOTIFY").."\n" .. table.dump(d2, "TEXT")
	SaveToFile("schedule", s)
end