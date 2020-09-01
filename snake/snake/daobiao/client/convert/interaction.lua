module(..., package.seeall)
function main()
	local d1 = require("qte.qte")
	local d2 = require("qte.text")
	
	local s = table.dump(d1, "QTEDATA").. "\n" .. table.dump(d2, "TEXT")
	SaveToFile("interaction", s)
end