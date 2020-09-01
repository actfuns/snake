module(..., package.seeall)
function main()
	local d1 = require("buff.state")

	
	local s = table.dump(d1, "buffState").. "\n" 
	SaveToFile("buffState", s)
end