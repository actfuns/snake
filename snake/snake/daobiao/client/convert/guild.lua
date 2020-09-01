module(..., package.seeall)
function main()
	local d1 = require("economic.guild.catalog")
	local d2 = {}--require("economic.guild.subcatalog")
	local d3 = require("economic.guild.iteminfo")
	local d4 = require("economic.guild.text")
	local d5 = {}

	local tData = {
		d1,d2,d3,d4,d5
	}

	local function Sort(c1, c2)
		return c1.sort < c2.sort
	end

	table.sort(d1, Sort)

	local function GetSubCatalog(cat_id, sub_id)
		for i,dInfo in ipairs(d2) do
			if dInfo.cat_id == cat_id and dInfo.subcat_id == sub_id then
				return dInfo, i
			end
		end
		return nil
	end

	for iGoodId,dInfo in pairs(d3) do
		local iCatId = dInfo.cat_id
		local iSubcatId = dInfo.sub_id

		local dSubCatalog, iIndex = GetSubCatalog(iCatId, iSubcatId)
		if dSubCatalog then
			dSubCatalog.slv = math.min(dSubCatalog.slv, dInfo.slv)
		elseif iSubcatId ~= 0 then
			dSubCatalog = {cat_id = iCatId, subcat_id = iSubcatId, subcat_name = dInfo.subcat_name, slv = dInfo.slv}
			table.insert(d2, dSubCatalog)
		end
		if not d5[dInfo.item_sid] then
			d5[dInfo.item_sid] = {}
		end
		table.insert(d5[dInfo.item_sid], iGoodId)
	end

	local tTitle = {
		[1] = "CATALOG",
		[2] = "SUBCATALOG",
		[3] = "ITEMINFO",
		[4] = "TEXT",
		[5] = "ITEM2GOOD"
	} 

	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	SaveToFile("guild", s)
end
