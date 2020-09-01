module(..., package.seeall)
function main()
    local mail = require("mail")
    local oMailList = {}
    for k, v in pairs(mail) do
		oMailList[k] = v
		oMailList[k].content = nil
	end

    local s = table.dump(oMailList, "INFO")
    SaveToFile("mail", s)
end
