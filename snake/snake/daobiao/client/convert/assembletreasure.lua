module(..., package.seeall)
function main()
	local s1 = require("huodong.jubaopen.rank_reward")
	local s2 = require("huodong.jubaopen.score_reward")
	local s3 = require("huodong.jubaopen.text")

	local s4 = require("reward.jubaopen_itemreward")
	local s5 = require("reward.jubaopen_reward")
	local s6 = require("huodong.jubaopen.config")

    local s = table.dump(s1, string.upper("rank_reward")) .. 
    "\n" ..table.dump(s2, string.upper("score_reward")) ..
    "\n" ..table.dump(s3, string.upper("text")) ..
    "\n" ..table.dump(s4, string.upper("jubaopen_itemreward")) ..
    "\n" ..table.dump(s5, string.upper("jubaopen_reward"))..
     "\n" ..table.dump(s6, string.upper("config"))

	SaveToFile("assembletreasure", s)
	
end
