module(..., package.seeall)
function main()
	local d1 = require("huodong.joyexpense.config")
	local d2 = require("huodong.joyexpense.reward_new")
	local d3 = require("huodong.joyexpense.reward_old")
	local d4 = require("huodong.joyexpense.text")
	
	local s = table.dump(d1, "CONFIG").. "\n" .. table.dump(d2, "REWARDNEW").. "\n" .. table.dump(d3, "REWARDOLD").. "\n" .. table.dump(d4, "TEXT")

	SaveToFile("rebatejoy", s)
end