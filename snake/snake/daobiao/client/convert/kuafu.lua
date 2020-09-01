module(..., package.seeall)
function main()
	local d1 = require("system.kuafu.config")
	local d2 = require("system.kuafu.text")
	
	local s = table.dump(d1, "CONFIG").. "\n" .. table.dump(d2, "TEXT")
	SaveToFile("kuafu", s)
end