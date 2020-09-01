module(..., package.seeall)
function main()
	local d1 = {}--require("economic.stall.catalog")
	local d2 = require("economic.stall.iteminfo")
	local d3 = require("economic.stall.text")

	for i,dInfo in pairs(d2) do
		local iCat_id = dInfo.cat_id
		local iSubcat_id = dInfo.subcat_id
		if not d1[iCat_id] then
			d1[iCat_id] = {cat_id = iCat_id, cat_name = dInfo.cat_name}
		end
	end

	local tData = {
		d1,d2,d3
	}

	local tTitle = {
		[1] = "CATALOG",
		[2] = "ITEMINFO",
		[3] = "TEXT",
	} 

	local s = ""
	for k,v in pairs(tTitle) do
		s = string.format("%s%s\n", s, table.dump(tData[k], v))
	end
	SaveToFile("stall", s)
end
