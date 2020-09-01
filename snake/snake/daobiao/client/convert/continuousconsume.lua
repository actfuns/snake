module(..., package.seeall)
function main()
    local list = {"new_reward","old_reward","new_total_reward","old_total_reward"}
    local s
    for i, name in ipairs(list) do
        local d = require("huodong.continuousexpense."..name)
        local str = table.dump(d, string.upper(name))
        if not s then
            s = str
        else
            s = s .. "\n" .. str
        end
    end
    SaveToFile("continuousconsume", s)
end