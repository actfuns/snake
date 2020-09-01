module(..., package.seeall)
function main()
    local d1 = require("system.promote.promote")
    local d2 = require("system.promote.judge")
    local d3 = require("system.promote.warfail")
    local d4 = require("huodong.grow.config")
    local d5 = require("system.promote.biaozhun")
    local info = {}
 	local typeTable = {1,2,3,4,5,6,7}
    -- for k,v in pairs(d1) do
    --     if typeTable[v.type] == nil then
    --        --typeTable[#typeTable + 1] = v.type
    --        table.insert(typeTable,v.type)
    --     end
    -- end
    for k,v in pairs(d1) do
        for i,value in ipairs(typeTable) do
            if info[i] == nil then
               info[i] = {}
            end
            if v.type == i then
               table.insert(info[i],v) 
            end
        end
    end

    -- 标准推荐评分
    local refrence_score = {}
    for i, v in pairs(d5) do
        local t = {reference_score = v.reference_score}
        refrence_score[i] = t
    end
    
	local s = table.dump(info, "DATA").."\n"..table.dump(d2, "JUDGE").."\n"..table.dump(d3, "WARFAIL").."\n"..table.dump(d4, "GROW")
            .."\n"..table.dump(refrence_score, "SCORE")
	SaveToFile("promote", s)
end
