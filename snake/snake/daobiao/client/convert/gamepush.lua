module(..., package.seeall)
function main()
	local d1 = require("system.gamepush.gamepush")

    local s = table.dump(d1, "DATA")
	SaveToFile("gamepush", s)
end

