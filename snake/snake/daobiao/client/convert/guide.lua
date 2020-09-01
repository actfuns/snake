module(..., package.seeall)
function main()
	local d1 = require("system.guide.guide_notplay")
	local d2 = require("system.guide.guide_hasplay")
	local d3 = require("system.guide.guide_option")
	local d4 = require("system.guide.newbie_summon")
	
	local s = table.dump(d1, "GUIDENOTPLAY").. "\n" .. table.dump(d2, "GUIDEHASPLAY") .. "\n" .. table.dump(d3, "GUIDEOPTION") .. "\n" .. table.dump(d4, "NEWBIESUMMON")
	SaveToFile("guideconfig", s)
end