module(..., package.seeall)
function main()
    local d1 = require("huodong.retrieveexp.retrieve")
    local d2 = require("huodong.retrieveexp.config")
    local s = table.dump(d1, "retrieve").."\n"..table.dump(d2, "config")
    SaveToFile("exprecycle", s)
end