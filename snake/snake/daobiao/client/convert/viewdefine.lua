module(..., package.seeall)
function main()
    local d = require("viewdefine")
    local detailDefine = {}
    local map = {}
    local clsnameMap = {}
    local define = {}
    for k, data in pairs(d) do
    	local tabs_1 = {}
        local tabs_2 = {}
    	for i,tab in pairs(data.tab_list) do
    		tabs_1[tab.tab_name] = tab.tab_id
            if tab.tab_ename then 
                tabs_2[tab.tab_ename] = tab.tab_id 
            end
    	end
    	detailDefine[k] = {
    		sys_name = data.sys_name,
    		cls_name = data.cls_name,
    		tab = tabs_1,
            open_sys = data.open_sys,
    	}
        map[data.id] = k
        clsnameMap[data.cls_name] = data.short_name
        define[data.short_name] = {
            id = data.id,
            tab = tabs_2
        }
    end
    local s = table.dump(detailDefine, "DETAIL_DEFINE")..table.dump(map, "MAP")..table.dump(define, "DEFINE")..table.dump(clsnameMap, "CLS2SYS")
    SaveToFile("viewdefine", s)
end
