module(..., package.seeall)
function main()
	local npcshop = require("economic.store.npcstore")
	local gmshop = require("economic.store.gmshop")
	local gmShopItemDic = {}
	for _,v in pairs(gmshop) do
		if not gmShopItemDic[v.tag_name] then
			gmShopItemDic[v.tag_name] = {}
		end
		table.insert(gmShopItemDic[v.tag_name], v)
	end
	local s = table.dump(npcshop, "NPCSHOP") .. "\n" .. table.dump(gmShopItemDic, "GMSHOP")
	SaveToFile("shop", s)
end
