module(..., package.seeall)
function main()
	local d1 = require("system.barrage.text")
	local d2 = require("system.barrage.barrage_global")
	local d3 = require("system.barrage.war_barrage_name")
	
	local s = table.dump(d1, "TEXT").. "\n" .. table.dump(d2, "GLOBAL") .. "\n" .. table.dump(d3, "WARBARRAGENAME")
	SaveToFile("barrage", s)
end