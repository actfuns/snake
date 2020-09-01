module(..., package.seeall)
function main()
	local d1 = require("system.rank.ranktype")
	local d2 = require("system.rank.rankinfo")
	local d3 = require("system.rank.dialog")
    local d4 = require("system.rank.reward")
	local s = table.dump(d1, "TYPE").."\n"..table.dump(d2,"INFO").."\n"..table.dump(d3,"DIALOG").."\n"..table.dump(d4,"REWARD")
	SaveToFile("rank", s)
end
