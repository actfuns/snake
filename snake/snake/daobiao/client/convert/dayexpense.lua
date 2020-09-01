module(..., package.seeall)
function main()
	local d1 = require("huodong.dayexpense.config")
	local d2 = require("huodong.dayexpense.reward")
	local d3 = require("huodong.dayexpense.text")
	local s = table.dump(d1, string.upper("config")) ..
	"\n"..table.dump(d2, string.upper("reward"))..
	"\n"..table.dump(d3, string.upper("text"))
	SaveToFile("dayexpense", s)
end