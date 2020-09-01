local global = require "global"

local aibase = import(service_path("ai/aibase"))

function NewAI(...)
    local o = CAI:New(...)
    return o
end

CAI = {}
CAI.__index = CAI
inherit(CAI, aibase.CAI)

function CAI:New(iAI)
    local o = super(CAI).New(self,iAI)
    return o
end

function CAI:Command(oAction)
    local oWar = oAction:GetWar()
    if oWar then
        local mCmd = {
            cmd = "defense",
        }
        oWar.m_mBoutCmds[oAction.m_iWid] = mCmd
    end
end
