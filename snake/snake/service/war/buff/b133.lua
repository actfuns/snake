local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

--星灵禁锢

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end


CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior, oBuffMgr)
    local func = function(oAction, mCmd)
        return ChangeCmd(oAction, mCmd)
    end
    oBuffMgr:AddFunction("ChangeCmd", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("ChangeCmd", self.m_ID)
end

function ChangeCmd(oAction, mCmd)
    if mCmd and mCmd.cmd == "skill" then
        if math.random(100) > 40 then return end

        local iPerform = mCmd.data.skill_id
        local oPerform = oAction:GetPerform(iPerform)
        if not oPerform then return end

        if oPerform:AttackType() ~= gamedefines.WAR_PERFORM_TYPE.PHY then
            return
        end

        local lTarget = oPerform:TargetList(oAction)
        if not lTarget or not next(lTarget) then
            return
        end

        local oTarget = lTarget[math.random(#lTarget)]
        mCmd.data.select_wlist = {oTarget:GetWid()}
        return mCmd
    end
    if mCmd and mCmd.cmd == "normal_attack" then
        local lEnemy = oAction:GetEnemyList()
        if not next(lEnemy) then return end

        local oTarget = lEnemy[math.random(#lEnemy)]
        mCmd.data.select_wid = oTarget:GetWid()
        return mCmd
    end
end
