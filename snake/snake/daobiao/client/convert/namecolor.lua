module(..., package.seeall)
function main()
	local d1 = require("namecolor")
	local d2 = require ("titlecolor")
    local s = table.dump(d1, "DATA").."\n"..table.dump(d2, "TITLEDATA")
	SaveToFile("namecolor", s)
end

