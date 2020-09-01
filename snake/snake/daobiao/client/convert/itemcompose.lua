module(..., package.seeall)
function main()
	-- path 表名称 name 导出数据表关键字
	local nameList = {
		{path = "itemcompound", name = "itemcompound"},
		{path = "catalog",      name = "catalog"},
		{path = "subcatalog",   name = "subcatalog"},		
	}
    local s
	for _,v in ipairs(nameList) do
		local t = table.dump(require("item." .. v.path), string.upper(v.name))
        if not s then
            s = t
        else
            s = s .. "\n" .. t
        end
	end
	local item2cat = {}
	local data = require("item.catalog")
	for i,v in ipairs(data) do
		if v.item_id ~= 0 then
			if not item2cat[v.item_id] then
				item2cat[v.item_id] = {}
			end
			table.insert(item2cat[v.item_id], {cat_id = v.cat_id, subcat_id = 0})
		end
	end

	local data = require("item.subcatalog")
	for i,v in ipairs(data) do
		if not item2cat[v.item_id] then
			item2cat[v.item_id] = {}
		end
		table.insert(item2cat[v.item_id], {cat_id = v.cat_id, subcat_id = v.subcat_id})
	end
	s = s .. "\n" .. table.dump(item2cat, string.upper("item2cat"))

	local item2Compose = {}
	local data = require("item.itemcompound")
	for k,v in pairs(data) do
		local itemid = v.sid_item_list[1].sid
		if not item2Compose[itemid] then
			item2Compose[itemid] = {}
		end
		table.insert(item2Compose[itemid], k)
	end
	s = s .. "\n" .. table.dump(item2Compose, string.upper("item2Compose"))

	SaveToFile("itemcompose", s)
end
