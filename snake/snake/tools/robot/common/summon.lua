require("tableop")
local res = require "data"
local extend = require('extend')

local summon = {}

summon.GS2CLoginSummon = function(self, args)
    self:sleep(math.random(6, 8))
    local lSummon = table_key_list(res["summon"]["info"])
    local iSummon = lSummon[math.random(1, #lSummon)]
    self:run_cmd("C2GSGMCmd", {cmd=string.format("givesummon %s 0", iSummon)})
end

summon.GS2CAddSummon = function(self, args)
    if args.summondata then
        local iSummon = args.summondata.id
        local sCmd = string.format([[runstring "oMaster.m_oSummonCtrl:Follow(%s)"]], iSummon)
        self:run_cmd("C2GSGMCmd", {cmd=sCmd})
    end
end

return summon
