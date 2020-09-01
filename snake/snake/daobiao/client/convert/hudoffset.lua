module(..., package.seeall)
function main()
	local d = require("system.role.hudoffset")

    local s = table.dump(d, "DATA")
	SaveToFile("hudoffset", s)
end

