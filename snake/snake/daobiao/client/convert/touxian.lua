module(..., package.seeall)
function main()
    local d1 = require("system.touxian.touxian")
    local text  = require("system.touxian.text")
    
    local s = table.dump(d1, "DATA").. "\n" .. 
              table.dump(text, "TEXT")
    SaveToFile("touxian", s)
end