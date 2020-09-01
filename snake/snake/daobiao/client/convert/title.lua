module(..., package.seeall)
function main()
    local text = require("system.title.text")
    local title = require("system.title.title")
    local titledescfield = require("system.title.titledescfield")

    local s = table.dump(title, "INFO") .. "\n" .. 
              table.dump(titledescfield, "DESC_FIELD") .. "\n" .. 
              table.dump(text, "TEXT")
    SaveToFile("title", s)
end