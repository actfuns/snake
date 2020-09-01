module(..., package.seeall)
function main()
	local recoveryitem = require("system.recovery.recoveryitem")
	local recoverysum = require("system.recovery.recoverysum")
    local s = table.dump(recoveryitem, "RECOVERYITEM") .. "\n" ..table.dump(recoverysum, "RECOVERYSUM") 
	SaveToFile("recovery", s)
	
end
