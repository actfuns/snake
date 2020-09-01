module(..., package.seeall)
function main()
	local d1 = require("system.role.attrname")

	local s = table.dump(d1, "DATA").."\n"
	SaveToFile("attrname", s)
end
