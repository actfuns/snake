local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

--霸剑诀

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oActioin, oBuffMgr)
    local func = function(oVictim, mCmd)
        return ChangeCmd(oVictim, mCmd)
    end
    oBuffMgr:AddFunction("ChangeCmd", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("ChangeCmd", self.m_ID)
end

function ChangeCmd(oVictim, mCmd)
    if not oVictim then return mCmd end

    local oWar = oVictim:GetWar()
    if not oWar then return mCmd end

    local oBuff = oVictim.m_oBuffMgr:HasBuff(170)
    if not oBuff then return mCmd end

    local iFocus = oBuff:ActionWid()
    if not iFocus then return mCmd end

    local oAction = oWar:GetWarrior(iFocus)
    if not oAction or oAction:IsDead() then
        return mCmd
    end

    if mCmd.cmd == "skill" then 
        mCmd.data.select_wlist = {iFocus}
    elseif mCmd.cmd == "normal_attack" then
        mCmd.data.select_wid = iFocus
    end
    return mCmd
end

