module(..., package.seeall)
function main()
	local d = require("item.itemfilter")

	local t = {}

	for i, v in ipairs(d) do
		t[i] = v
	end

    local s = table.dump(t, "DATA")
	SaveToFile("itemfilter", s)
end

