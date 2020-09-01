module(..., package.seeall)
function main()
    local others = require("system.org.others")
    local honorid = require("system.org.honorid")
    local positionid = require("system.org.positionid")
    local positionlimit = require("system.org.positionlimit")
    local positionauthority = require("system.org.positionauthority")
	local buildlevel = require("system.org.buildlevel")
	local buildquick = require("system.org.quick")
	local buildshop =  require("system.org.shop")
	local welfare = require("system.org.welfare")
	local achieve = require("system.org.achieve")
    local text = require("system.org.text")
    local activity = require("system.org.orgactivity")
	local level = {}
	for k, v in pairs(buildlevel) do
		if level[v.build_id] == nil then 
			level[v.build_id] = {}
		end
		level[v.build_id][v.level] = {}
		level[v.build_id][v.level] = v
	end
	local goal = {}
	for k, v in pairs(achieve) do
		if goal[v.tag_name] == nil then 
			goal[v.tag_name] = {}
		end
		table.insert(goal[v.tag_name], v)
	end
	for k, v in pairs(goal) do
		table.sort(v,function(v1, v2)
			return v1.id < v2.id
		end)
	end 
	local weekactivity = {}
	for i=1,7 do
		weekactivity[i] = {}
	end
	for i,v in pairs(activity) do
		for _,date in ipairs(v.date_list) do
			table.insert(weekactivity[date], v)
		end
	end
	local sortTime = function(d1, d2)
		return d1.time < d2.time
	end
	for i,activityList in pairs(weekactivity) do
		table.sort(activityList, sort)
	end

    local s = table.dump(others, "OTHERS") .. "\n" .. 
              table.dump(honorid, "HONORID") .. "\n" ..
              table.dump(positionid, "POSITIONID") .. "\n" ..
              table.dump(positionlimit, "POSITIONLIMIT") .. "\n" ..
              table.dump(positionauthority, "POSITIONAUTHORITY") .. "\n" ..
			  table.dump(level, "BUILDLEVEL").."\n"..
			  table.dump(buildquick, "BUILDQUICK").."\n"..
			  table.dump(buildshop, "BUILDSHOP").."\n"..
			  table.dump(welfare, "WELFARE").."\n"..
			  table.dump(goal, "GOAL").."\n"..
              table.dump(text, "TEXT").."\n"..
              table.dump(activity, "ACTIVITY").."\n"..
              table.dump(weekactivity, "WEEKACTIVITY")
    SaveToFile("org", s)
end
