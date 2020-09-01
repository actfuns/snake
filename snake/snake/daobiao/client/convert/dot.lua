module(..., package.seeall)
function main()
	local d1 = require("dot")
	
	local s = table.dump(d1, "DOT")
	SaveToFile("dot", s)
end