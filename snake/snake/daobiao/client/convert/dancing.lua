module(..., package.seeall)
function main()
    local condition = require("huodong.dance.condition")

    local s = table.dump(condition, "CONDITION")
    SaveToFile("dance", s)
end