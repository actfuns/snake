module(..., package.seeall)
function main()
	local d1 = require("system.redpacket.text")
	local d2 = require("system.redpacket.basic")
	local d3 = require("system.redpacket.se")
	local d4 = require("system.redpacket.cashtype")
	local d5 = require("system.redpacket.personnum")
	local d6 = require("system.redpacket.global")
	
	local s = table.dump(d1, "TEXT").. "\n" .. table.dump(d2, "SYSREDPACKET").. "\n" .. table.dump(d3, "REDPACKETEFFECT").. "\n" .. table.dump(d4, "CASHTYPE")
	.. "\n" .. table.dump(d5, "PERSONNUM").. "\n" .. table.dump(d6, "GLOBAL")
	SaveToFile("redpacket", s)
end