module(..., package.seeall)
function main()
	local d1 = require("fuben.config")
    local d2 = require("huodong.jyfuben.clientconfig")

    local s = table.dump(d1, "DATA").."\n"..table.dump(d2, "ELITE")
    
    local fights = {"fuben_tollgate","fuben_monster","jyfuben_tollgate","jyfuben_monster"}
    for i, v in ipairs(fights) do
        local f = require("fight."..v)
        local d = {}
        if string.match(v, "tollgate") then
            for k, u in pairs(f) do
                local g = {}
                g.id = u.id
                g.monster = u.monster
                d[k] = g
            end
        elseif string.match(v, "monster") then
            for k, u in pairs(f) do
                local g = {}
                g.id = u.id
                g.name = u.name
                g.figureid = u.figureid
                g.is_boss = u.is_boss
                d[k] = g
            end
        end
        s = s .. "\n" .. table.dump(d, string.upper(v))
    end

    local jyTasks = {"grouptask","floorreward","taskevent"}
    for i, v in ipairs(jyTasks) do
        local d = require("task.jyfuben."..v)
        s = s .. "\n" .. table.dump(d, string.upper("jy_"..v))
    end

	SaveToFile("fuben", s)
end

