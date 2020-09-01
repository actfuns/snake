module(..., package.seeall)
function main()
	local d1 = require("system.chat.helpchat")
	
	local d2 = require("system.chat.chatconfig")
	local chatconfig = {}
	for k, v in pairs(d2) do
		chatconfig[v.id] = {
			name = v.name,
			sort = v.sort,
			talkable = v.talkable,
			talk_gap = v.talk_gap,
			voiceable = v.voiceable,
			energy_cost = v.energy_cost,
			grade_limit = v.grade_limit,
			define = v.define,
		}
	end

	local d3 = require("system.chat.text")
	local d4 = require("system.chat.chuanyin")
	local d5 = require("system.chat.textemoji")
	
	local s = table.dump(d1, "HELP") .. "\n" .. table.dump(chatconfig, "CHATCONFIG") ..  table.dump(d3, "TEXT").. "\n" .. table.dump(d4, "MILES").. "\n" .. table.dump(d5, "TEXTEMOJI")
	SaveToFile("chat", s)
end