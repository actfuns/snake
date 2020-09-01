module(..., package.seeall)
function main()
	local d1 = require("instruction")
	local s = table.dump(d1, "DESC")
	SaveToFile("instruction", s)
end
