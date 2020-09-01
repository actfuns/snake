module(..., package.seeall)
function main()
	-- path 表名称 name 导出数据表关键字
	local nameList = {
		{path = "warfailshow",	name = "warfailshow"},
		{path = "warfailconfig",	name = "warfailconfig"},
	}
    local s
	for _,v in ipairs(nameList) do
		local t = table.dump(require("system.warconfig." .. v.path), string.upper(v.name))
        if not s then
            s = t
        else
            s = s .. "\n" .. t
        end
	end
	SaveToFile("warfailconfig", s)
end
