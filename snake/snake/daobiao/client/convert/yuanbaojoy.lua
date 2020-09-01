module(..., package.seeall)
function main()
	local d1 = require("huodong.goldcoinparty.degree_reward")
	local d2 = require("huodong.goldcoinparty.lottery_reward")
	local d3 = require("huodong.goldcoinparty.config")
	local d4 = require("huodong.goldcoinparty.text")
	
	local s = table.dump(d1, "BAOXIANGREWARD").. "\n" .. table.dump(d2, "PRIZEREWARD").. "\n" .. table.dump(d3, "CONFIG").. "\n" .. table.dump(d4, "TEXT")
	SaveToFile("yuanbaojoy", s)
end