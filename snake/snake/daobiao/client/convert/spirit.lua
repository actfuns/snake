module(..., package.seeall)
function main()
	local d1 = require("system.guide.spirit_option")
	local d2 = require("system.guide.spirit_item")
	
	local s = table.dump(d1, "SPIRITOPTION").. "\n" .. table.dump(d2, "SPIRITITEM")
	SaveToFile("spirit", s)
end