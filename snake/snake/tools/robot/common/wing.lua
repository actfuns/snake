require("tableop")
local res = require "data"
local extend = require('extend')

local wing = {}

wing.GS2CLoginWing = function(self, args)
    local lTimeWing = {}
    for _, mTimeWing in pairs(res["wing"]["wing_info"]) do
        if mTimeWing.time_wing == 1 then
            table.insert(lTimeWing, mTimeWing.wing_id)
        end
    end
    self:sleep(math.random(1, 8))
    local iSetWing = lTimeWing[math.random(#lTimeWing)]
    self:run_cmd("C2GSGMCmd", {cmd=string.format("setshowwing %s", iSetWing)})
end

return wing
