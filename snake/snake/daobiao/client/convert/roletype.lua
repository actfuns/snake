module(..., package.seeall)
function main()
	local d1 = require("system.role.roletype")
	local d2 = require("system.role.race")
	local d3 = require("system.role.chubeiexplimit")
	local s = table.dump(d1, "DATA") .. "\n" .. table.dump(d2, "Race") .. "\n" ..table.dump(d3, "LIMIT")
	SaveToFile("roletype", s)
end
