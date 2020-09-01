module(..., package.seeall)
function main()
	local d1 = require("item.hunshi_color")
	local d2 = require("item.hunshi_attr")
	local d3 = require("item.hunshi_combineratio")
	local d4 = require("item.hunshi_equiplimit")
	local d5 = require("item.hunshi_equipcolor")
	local d6 = require("item.hunshi_lianhua")
	local d7 = {}
	local d8 = {}
	local d9 = {}
	local d10 = {}

	local tTitle = {
		[1] = "COLOR",
		[2] = "ATTR",
		[3] = "COMPOSE",
		[4] = "EQUIPLIMIT",
		[5] = "EQUIPCOLOR",
		[6] = "REFINE",
		[7] = "ITEM2COLOR",
		[8] = "COLOR2ATTR",
		[9] = "KEY2ATTR",
		[10] = "UNLOCK"
	} 

	local tData = {
		d1,d2,d3,d4,d5,d6,d7,d8,d9,d10
	}

	for i,v in ipairs(d1) do
		d7[v.itemsid] = v.color
	end

	for i,v in ipairs(d2) do
		if not d8[v.color] then
			d8[v.color] = {}
		end
		d8[v.color][v.attr] = v
		d9[v.attr_key] = v.attr
	end

	for i,v in pairs(d4) do
		local unlockLv = d10[v.holecnt]
		if not unlockLv then
			d10[v.holecnt] = v.grade
		else
			d10[v.holecnt] = math.min(unlockLv, v.grade)
		end
	end

	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	-- local s = table.dump(d1, "EQUIP_ATTR").."\n"..table.dump(d2, "ATTACH_ATTR").."\n"..table.dump(d3, "WASH").."\n"..table.dump(d4, "EQUIP_LEVEL").."\n"..table.dump(d5, "SOUL_EFFECT").."\n"..table.dump(d6, "SOUL_MERGE").."\n"
	SaveToFile("hunshi", s)
end
