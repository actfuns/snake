module(..., package.seeall)
function main()
	-- path 表名称 name 导出数据表关键字
	local nameList = {
		{path = "itemother", 	name = "other"},
		{path = "itemvirtual",	name = "virtual"},
		{path = "itemgroup",	name = "itemgroup"},
		{path = "equip",		name = "equip"},
		{path = "summskill",	name = "summskill"},
		{path = "fu",			name = "forge"},
		{path = "equipbook",	name = "equipbook"},
		{path = "shenhun",		name = "equipsoul"},
		{path = "partner",		name = "partner"},
		{path = "partnerequip",	name = "partnerequip"},
		{path = "totask",		name = "totask"},
		{path = "giftpack",		name = "giftpack"},
		{path = "box",			name = "box"},
		{path = "summon",		name = "summon"},
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
	SaveToFile("item", s)
end
