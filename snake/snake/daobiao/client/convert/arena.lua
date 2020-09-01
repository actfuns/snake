module(..., package.seeall)
function main()
	local text = require("huodong.arena.text")
    local s = table.dump(text, "TEXT")
	SaveToFile("arena", s)
end

