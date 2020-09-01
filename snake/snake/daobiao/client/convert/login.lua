module(..., package.seeall)
function main()
	local d1 = require("system.login.text")
	
	local s = table.dump(d1, "TEXT")
	SaveToFile("login", s)
end