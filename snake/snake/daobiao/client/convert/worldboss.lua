module(..., package.seeall)
function main()
	local d1 = require("huodong.mengzhu.condition")
	local d2 = require("huodong.mengzhu.text")

    local s = table.dump(d1, "DATA").."\n"..table.dump(d2, "TEXT")
	SaveToFile("worldboss", s)
end

