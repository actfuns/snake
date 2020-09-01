module(..., package.seeall)
function main()
	local d1 = require("system.summon.washcost")
	local d2 = require("system.summon.autopoint")
	local d3 = require("system.summon.summoninfo")
	local d4 = require("system.summon.skillcost")
	local d5 = require("skill.summon")
    local d6 = require("system.summon.store")
	local d7 = require("system.summon.element")
	local d8 = require("system.summon.race")
	local d9 = require("system.summon.summtype")
	local d10 = require("system.summon.score")
	local d11 = require("system.summon.bianyi")
	local d12 = require("system.summon.aptitudepellet")
	local d13 = require("system.summon.text")
	local d14 = require("system.summon.xiyou")
	local d15 = require("system.summon.grow")
	local d16 = require("system.summon.calformula")
	local d17 = require("system.summon.fixedproperty")
	local d18 = require("system.summon.shenshouexchange")
	local d19 = require("system.summon.aptitcombine")
	local d20 = require("system.summon.shenshouadvance")
	local d21 = require("system.summon.xyshenshouadvance")
	local d22 = require("system.summon.xyzhenshouadvance")
	local usegrade = {}
	for k, v in pairs(d6) do
		if usegrade[v.usegrade] == nil then
			usegrade[v.usegrade] = {}
		end
		table.insert(usegrade[v.usegrade], k)
	end
	local s = table.dump(d1, "WASHDATA").."\n"..table.dump(d2,"POINTDATA").."\n"..table.dump(d3,"INFO").."\n"..table.dump(d4,"SKILLCOST").."\n"..table.dump(d5,"SKILL").."\n"..table.dump(d6,"STORE").."\n"..table.dump(usegrade,"USEGRADE").."\n"..table.dump(d7,"ELEMENT").."\n"..table.dump(d8,"RACE").."\n"..table.dump(d9,"SUMMTYPE").."\n"..table.dump(d10,"SCORE").."\n"..table.dump(d11,"COMPOUNDTYPE").."\n"..table.dump(d12,"APTITUFEPELLET").."\n"..table.dump(d13,"TEXT").."\n"..table.dump(d14,"XIYOU").."\n"..table.dump(d15,"GROW") .. "\n".. table.dump(d16, "calformula") .. "\n" .. table.dump(d17, "FIXEDPROPERTY") .. "\n" .. table.dump(d18, "SPCEXCHANGE") .. "\n" .. table.dump(d19, "APTITCOMBINE") .. table.dump(d20, "ADVANCE") .. "\n" .. table.dump(d21, "XY_ADVANCE") .. "\n" .. table.dump(d22, "XY_ZS_ADVANCE")
	SaveToFile("summon", s)
end
