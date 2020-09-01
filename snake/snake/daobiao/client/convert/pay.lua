module(..., package.seeall)
function main()
	local pay = require("pay.pay")
    local s = table.dump(pay, "PAY")
	SaveToFile("pay", s)
end
