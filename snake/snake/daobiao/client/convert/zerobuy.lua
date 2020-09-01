module(..., package.seeall)
function main()
	local d1 = require("huodong.zeroyuan.config")
	local d2 = require("huodong.zeroyuan.activity")
	
	local s = table.dump(d1, "CONFIG").. "\n" .. table.dump(d2, "ACTIVITY")
	SaveToFile("zerobuy", s)
end