local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

-- 嘲讽
function CBuff:CalInit(oAction, oBuffMgr)
    local iMockWid = self:ActionWid()
    local func = function(oAction, mCmd, sType)
        return ChangeCmd(oAction, mCmd, iMockWid, sType)
    end
    oBuffMgr:AddFunction("ChangeCmd", self.m_ID, func)
end

function CBuff:OnRemove(oAction, oBuffMgr)
    super(CBuff).OnRemove(self, oAction, oBuffMgr)
    oBuffMgr:RemoveFunction("ChangeCmd", self.m_ID)
end

function ChangeCmd(oAction, mCmd, iMockWid, sType)
    if sType ~= "use" then return mCmd end

    local oTarget = oAction:GetWarrior(iMockWid)
    if not oTarget or oTarget:IsDead() then return mCmd end

    if mCmd and mCmd.cmd == "normal_attack" then
        mCmd.data.select_wid = oTarget:GetWid()
        return mCmd
    end
    if mCmd and mCmd.cmd == "skill" then
        local iPerform = mCmd.data.skill_id
        local oPerform = oAction:GetPerform(iPerform)
        if not oPerform then return mCmd end

        if oPerform:TargetType() ~= 2 then
            local mNewCmd = {
                cmd = "normal_attack",
                data = {
                    action_wid = iActionWid,
                    select_wid = iMockWid,
                }
            }
            return mNewCmd
        end
        mCmd.data.select_wlist = {oTarget:GetWid()}
        return mCmd
    end
end
