module(..., package.seeall)
function main()
	local d1 = require("economic.auction.auction")
	local d2 = require("economic.auction.text")

	local tData = {
		d1,d2
	}

	local tTitle = {
		[1] = "ITEMINFO",
		[2] = "TEXT",
	} 

	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	SaveToFile("auction", s)
end
