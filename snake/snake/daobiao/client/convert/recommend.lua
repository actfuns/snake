module(..., package.seeall)

function main()
	local d1 = require("huodong.foreshow.giftday")
	local d2 = require("huodong.foreshow.activepoint")
	local d3 = require("huodong.foreshow.weekday")

	local s = table.dump(d1, "GIFTDAY") .. "\n" .. table.dump(d2, "ACTIVEPOINT") .. "\n" .. table.dump(d3, "WEEKDAY")
	SaveToFile("recommend", s)
end