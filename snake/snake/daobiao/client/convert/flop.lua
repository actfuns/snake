module(..., package.seeall)
function main()
	local d1 = require("huodong.drawcard.config")
	local d2 = require("huodong.drawcard.times_cost")
	local d3 = require("huodong.drawcard.text")
	
	local s = table.dump(d1, "CONFIG").. "\n" .. table.dump(d2, "TIMECOST").. "\n" .. table.dump(d3, "TEXT")
	SaveToFile("flop", s)
end