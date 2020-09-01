module(..., package.seeall)
function main()
	local d = require("fight.shimen_monster")
	local s = table.dump(d, "DATA")
	SaveToFile("fightshimen", s)
end
