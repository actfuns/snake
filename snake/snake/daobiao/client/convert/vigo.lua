module(..., package.seeall)
function main()
	local d1 = require("system.vigo.config")
    local d2 = require("system.vigo.text")
    local d3 = require("system.vigo.other")

    local s = table.dump(d1, "DATA").."\n"..table.dump(d2, "TEXT").."\n"..table.dump(d3, "OTHER")
	SaveToFile("vigo", s)
end

