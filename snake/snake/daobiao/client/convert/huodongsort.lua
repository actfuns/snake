module(..., package.seeall)
function main()
	local d1 = require("huodong.huodongsort.welfare")

	local welfare = {}
	for i, v in pairs(d1) do
		local sys = v.stype
		welfare[sys] = v.sort_idx
	end

	local s = table.dump(welfare, string.upper("welfare"))
	
	SaveToFile("sort", s)
end