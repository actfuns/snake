module(..., package.seeall)
function main()
	local d1 = require("huodong.superrebate.config")
	local d2 = require("huodong.superrebate.rebate")
	local d3 = require("huodong.superrebate.pay")
	local d4 = require("huodong.superrebate.text")
	local s = table.dump(d1, string.upper("config")) ..
	"\n"..table.dump(d2, string.upper("rebate"))..
	"\n"..table.dump(d3, string.upper("pay"))..
	"\n"..table.dump(d4, string.upper("text"))
	SaveToFile("superrebate", s)
end