module(..., package.seeall)
function main()
    local open = require("open")
    local d2 = require("preopen")

    local s = table.dump(open, "OPEN").. "\n" .. table.dump(d2, "PREOPEN")
    SaveToFile("open", s)
end