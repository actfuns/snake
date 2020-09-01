module(..., package.seeall)
function main()
	local d1 = require("global")
	local d2 =require("system.summon.config")
	local s = table.dump(d1, "GLOBAL").."\n"..table.dump(d2, "SUMMONCK")

	SaveToFile("global", s)
end
