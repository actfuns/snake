module(..., package.seeall)
function main()
	local d1 = require("yechannel")

    local s = table.dump(d1, "CHANNEL")
	SaveToFile("yechannel", s)
end

