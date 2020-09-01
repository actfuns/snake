module(..., package.seeall)
function main()
	local d1 = require("system.ranse.hair")
	local d2 = require("system.ranse.clothes")
	local d3 = require("system.ranse.summon")
	local d4 = require("system.ranse.shizhuang")
	local d5 = require("system.ranse.text")
	local d6 = require("system.ranse.color")
	local d7 = require("system.ranse.sz_basic")
	local d8 = require("system.ranse.pant")
	local d9 = require("system.ranse.sz_map")

	local s = table.dump(d1, "HAIR").. "\n" .. table.dump(d2, "CLOTHES") .. "\n" .. table.dump(d3, "SUMMON") .. "\n" .. table.dump(d4, "SHIZHUANG") .. "\n" 
				.. table.dump(d5, "TEXT") .. "\n" .. table.dump(d6, "COLOR") .. "\n" .. table.dump(d7, "SZBASIC") .. "\n" .. table.dump(d8, "PANT") 
				.. "\n" .. table.dump(d9, "SZMAP") 
	SaveToFile("ranse", s)
end