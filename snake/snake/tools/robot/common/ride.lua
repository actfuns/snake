require("tableop")
local res = require "data"
local extend = require('extend')

local ride = {}

ride.GS2CPlayerRideInfo = function(self, args)
    if self.m_iSetRide then return end
    
    self.m_iSetRide = 1
    self:sleep(math.random(6, 8))
    local lRides = table_key_list(res["ride"]["rideinfo"])
    local iRide = lRides[math.random(1, #lRides)]
    self:run_cmd("C2GSGMCmd", {cmd=string.format("addride %s 1", iRide)})
end

return ride
