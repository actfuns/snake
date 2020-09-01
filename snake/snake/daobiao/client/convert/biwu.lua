module(..., package.seeall)
function main()
	local biwutext = require("huodong.biwu.text")
	local d1 = require("huodong.threebiwu.scene")
	local d2 = require("huodong.biwu.npc")

	local s = table.dump(biwutext, "BIWUTEXT") .. "\n" .. table.dump(d1, "THREEBIWUSCENE") .. "\n" .. table.dump(d2, "BIWUNPC")
	SaveToFile("biwutext", s)
end