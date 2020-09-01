module(..., package.seeall)
function main()
	local dOri = require("system.friend.friendship")
	local text = require("system.friend.text")
	local d1 = require("system.friend.flower")
	local d2 = require("system.friend.flowerbless")
	local d3 = require("system.friend.effect")
    local s = table.dump(dOri, "FRIENDSHIP") .. "\n" .. table.dump(text, "FRIENDTEXT") .. "\n" .. table.dump(d1, "FLOWERSELECT") 
    .. "\n" .. table.dump(d2, "FLOWERBLESS") .. "\n" .. table.dump(d3, "FLOWEREFFECT")
	SaveToFile("friend", s)
end


