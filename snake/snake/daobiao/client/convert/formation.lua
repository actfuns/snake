module(..., package.seeall)
function main()
	local d1 = require("system.formation.baseinfo")
	local d2 = require("system.formation.iteminfo")
	local d3 = require("system.formation.attrinfo")
	local d4 = require("system.formation.useinfo")
	local d5 = require("system.formation.text")

	-- local tBaseInfo = {}
	-- local tExpInfo = nil
	-- for k,v in pairs(d1) do
	-- 	local dOne = {
	-- 		name = v.name,
	-- 		pos = v.pos,
	-- 		mutex = v.mutex,
	-- 		positive = v.positive,
	-- 		passive =  v.passive,
	-- 	}
	-- 	tBaseInfo[k] = dOne

	-- 	local expInfo = v.exp
	-- 	if expInfo and not tExpInfo then
	-- 		tExpInfo = expInfo
	-- 	end
	-- end

	local tData = {
		d1,d2,d3,d4,d5
	}

	local tTitle = {
		[1] = "BASEINFO",
		[2] = "ITEMINFO",
		[3] = "ATTRINFO",
		[4] = "USEINFO",
		[5] = "TEXT",
	} 

	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	SaveToFile("formation", s)
end
