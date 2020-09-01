module(..., package.seeall)
function main()
	local d1 = require("system.dazao.equip_fenjie")
	local d2 = require("system.dazao.fenjie_ku")
	local dConfig = {}

	dConfig.minlv = 1000
	for i,v in pairs(d1) do
		dConfig.minlv = math.min(tonumber(v.level), dConfig.minlv)
	end

	local itemdict = {}
	for i,v in pairs(d2) do
		itemdict[v.sid] = true
	end
	local itemlist = {}
	for k,v in pairs(itemdict) do
		table.insert(itemlist, k)
	end

	dConfig.itemlist = itemlist

	local s = table.dump(d1, "EQUIP_DECOMPOSE").."\n"..table.dump(d2, "DECOMPOSE_DATA").."\n"..table.dump(dConfig, "CONFIG")
	SaveToFile("equipdecompose", s)
end
