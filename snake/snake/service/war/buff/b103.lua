--import module

local global = require "global"
local skynet = require "skynet"

local buffbase = import(service_path("buff/buffbase"))

function OnNewBout(iBout, oAction)
    if not oAction then return end
    local oWar = oAction:GetWar()
    if not oWar then return end

    if iBout > oWar:CurBout() - 5 then return end

    local iMaxHp = oAction:GetMaxHp()
    oAction:RemoveFunction("OnNewBout",103)
    oAction:AddHp(iMaxHp)
end

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior,oBuffMgr)
    local War = oWarrior:GetWar()
    local iBout = War.m_iBout
    local func = function (oAction)
        OnNewBout(iBout, oAction)
    end
    oWarrior:AddFunction("OnNewBout",self.m_ID,func)
end
