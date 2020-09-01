module(..., package.seeall)
function main()
	local d1 = require("reward.lottery")
    local d2 = require("huodong.caishen.config")
    local d3 = require("huodong.caishen.cost")
	
	local s = table.dump(d1, "lottery").. "\n" .. table.dump(d2, "CAISHEN_CONFIG").."\n"..table.dump(d3,"CAISHEN_COST") 
	SaveToFile("lottery", s)
end