module(..., package.seeall)
function main()
	local itemcolor = require("itemcolor")
    local othercolor = require("othercolor")
    local chatcolor = require("chatcolor")
	
	local s = table.dump(itemcolor, "ITEM").."\n"..table.dump(othercolor, "OTHER").."\n"..table.dump(chatcolor, "CHAT")
	SaveToFile("colorinfo", s)
end