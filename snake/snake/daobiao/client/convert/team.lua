module(..., package.seeall)
function main()
	local d1 = require("system.team.catalog")
	local d2 = require("system.team.autoteam")
	local d3 = require("system.team.text")
	local d4 = require("system.team.warcmd")

	local s = table.dump(d1, "CATALOG")..table.dump(d2, "AUTO_TEAM")..table.dump(d3, "TEXT")..table.dump(d4, "WAR_CMD")
	SaveToFile("team", s)
end