module(..., package.seeall)
function main()
	-- path 表名称 name 导出数据表关键字
	local nameList = {
		{path = "wenshi",		name = "wenshi"},
		{path = "skill_list",	name = "wenshi_skill"},
		{path = "attr_list",    name = "attr_list" },
		{path = "color_config", name = "color_config"},
		{path = "grade_config", name = "grade_config"}
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
	SaveToFile("itemwenshi", s)
end
