module(..., package.seeall)
function main()
    local nameList ={
        {path = "config", name = "CONFIG"},
        {path = "up_level", name = "UPLEVEL"},
        {path = "level_limit", name = "LEVELLIMIT"},
        {path = "level_wing", name = "LEVELWING"},
        {path = "text", name = "TEXT"},
        {path = "wing_info", name = "WINGINFO"},
        {path = "wing_effect", name = "WINGEFFECT"},
        {path = "up_star", name = "UPSTAR"},
    }

    local s
    for _, v in ipairs(nameList) do
        local d = table.dump(require("system.wing."..v.path), v.name)
        if not s then
            s = d
        else
            s = s .. "\n" .. d
        end
    end
    SaveToFile("wing", s)
end