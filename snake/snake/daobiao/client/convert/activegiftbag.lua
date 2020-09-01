module(..., package.seeall)
function main()
	local c1 = require("huodong.activepoint.config")
    local c2 = require("huodong.activepoint.reward")
	local s = table.dump(c1, "CONFIG").. "\n" .. table.dump(c2, "REWARD")
    SaveToFile("activegiftbag", s)
end