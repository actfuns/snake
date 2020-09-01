module(..., package.seeall)
function main()
	local c1 = require("huodong.worldcup.country")
	local c2 = require("huodong.worldcup.phase_cost")
    local s = table.dump(c1, "CONFIG").. "\n" .. 
			  table.dump(c2, "COST")
    SaveToFile("worldcup", s)
end