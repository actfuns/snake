module(..., package.seeall)
function main()
	local d1 = require("system.dazao.equipattr")
	local d2 = require("system.dazao.attachattr")
	local d3 = require("system.dazao.wash_equip")
	local d4 = require("system.dazao.equiplevel")
	local d6 = require("system.dazao.shenhunmerge")
	local d7 = require("system.dazao.strength")
	local d8 = require("system.dazao.strength_material")
	local d9 = require("system.dazao.equip_break")
	local d10 = require("system.dazao.fuhunpoint")
	local d11 = require("system.dazao.strength_master")
	local d12 = require("system.dazao.shenhuneffect")
	local d13 = require("system.dazao.equipse")
	local d14 = require("system.dazao.equipsk")
	local dHelper = {}

	local tTitle = {
		[1] = "EQUIP_ATTR",
		[2] = "ATTACH_ATTR",
		[3] = "WASH",
		[4] = "EQUIP_LEVEL",
		[5] = "SOUL_MERGE",
		[6] = "STRENGTH",
		[7] = "STRENGTH_MATERIAL",
		[8] = "STRENGTH_BREAK",
		[9] = "SOUL_POINT",
		[10] = "HELPER",
		[11] = "STRENGTH_MASTER",
		[12] = "SOUL_EFFECT",
		[13] = "EQUIP_SE",
		[14] = "EQUIP_SK",
	} 

	local iMinLv = 100000000
	for k,v in pairs(d3) do
		iMinLv = math.min(iMinLv, v.level)
	end
	dHelper.WashLimit = iMinLv

	local tData = {
		d1,d2,d3,d4,d6,d7,d8,d9,d10,dHelper,d11,d12,d13,d14
	}
	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	-- local s = table.dump(d1, "EQUIP_ATTR").."\n"..table.dump(d2, "ATTACH_ATTR").."\n"..table.dump(d3, "WASH").."\n"..table.dump(d4, "EQUIP_LEVEL").."\n"..table.dump(d5, "SOUL_EFFECT").."\n"..table.dump(d6, "SOUL_MERGE").."\n"
	SaveToFile("equip", s)
end
