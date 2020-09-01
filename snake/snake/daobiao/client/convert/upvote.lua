module(..., package.seeall)
function main()
	local d = require("system.role.upvote")
	local s = table.dump(d, "DATA")
	SaveToFile("upvote", s)
end
