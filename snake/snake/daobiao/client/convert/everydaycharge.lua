module(..., package.seeall)
function main()
	-- local c1 = require("huodong.everydaycharge.config")
    local c2 = require("huodong.everydaycharge.reward")
	local s = table.dump(c2, "REWARD")
    -- table.dump(c1, "CONFIG").. "\n" .. 
    SaveToFile("everydaycharge", s)
end