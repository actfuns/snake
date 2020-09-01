module(..., package.seeall)
function main()
	local pay = require("system.warconfig.common")
    local s = table.dump(pay, "COMMON")
	SaveToFile("warconfig", s)
end
