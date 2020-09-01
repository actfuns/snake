module(..., package.seeall)
function main()
	local d1 = require("newbieguide.newbieguide")
	local s = table.dump(d1, "DATA")
	SaveToFile("newbieguide", s)
end
