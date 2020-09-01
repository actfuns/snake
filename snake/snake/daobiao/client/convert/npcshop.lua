module(..., package.seeall)
function main()
	local npcstore = require("economic.store.npcstore")
	local gmshop = require("economic.store.gmshop")
	local gmShopItemDic = {}
	for _,v in pairs(gmshop) do
		if not gmShopItemDic[v.tag_id] then
			gmShopItemDic[v.tag_id] = {}
		end
		table.insert(gmShopItemDic[v.tag_id], v)
	end
	local s = table.dump(npcstore, "NPCSTORE") .. "\n" .. table.dump(gmShopItemDic, "GMSHOP")
	SaveToFile("store", s)
end
