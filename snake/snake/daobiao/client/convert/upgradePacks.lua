module(..., package.seeall)
function main()
	local d1 = require("system.role.gradegift")

	
	local s = table.dump(d1, "upgradePacks").. "\n" 
	SaveToFile("upgradePacks", s)
end
