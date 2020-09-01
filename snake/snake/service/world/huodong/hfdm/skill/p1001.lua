-- 活动技能-金钟罩
local global = require "global"
local res = require "base.res"
local hfdmskill = import(service_path("huodong.hfdm.skill"))
local hfdmdefines = import(service_path("huodong.hfdm.defines"))
local huodonghfdm = import(service_path("huodong.hfdm.main"))

function GetTextData(iText)
    return huodonghfdm.GetTextData(iText)
end

function GetHuodong()
    return global.oHuodongMgr:GetHuodong("hfdm")
end

function NewSkill(iPid, iSkillId)
    return CHuodongSkill:New(iPid, iSkillId)
end

CHuodongSkill = {}
CHuodongSkill.__index = CHuodongSkill
inherit(CHuodongSkill, hfdmskill.CHuodongSkillBase)

function CHuodongSkill:New(iPid, iSkillId)
    local o = super(CHuodongSkill).New(self, iPid, iSkillId)
    return o
end

function CHuodongSkill:CanUse(iTarget)
    local bSucc, iErr, bResync = super(CHuodongSkill).CanUse(self, iTarget)
    if not bSucc then
        return bSucc, iErr, bResync
    end
    local iPid = self.m_iOwner
    if iTarget ~= iPid then
        return false, hfdmdefines.ERR_USE_SKILL.TARGET_FAIL, false
    end
    local oHuodong = GetHuodong()
    if not oHuodong:IsStateQuesTime() then
        return false, hfdmdefines.ERR_USE_SKILL.TIME_ERR, false
    end
    -- 允许未答题玩家使用技能
    -- local iMyPosAnswer = oHuodong:GetPosAnswer(iPid)
    -- if not iMyPosAnswer then
    --     return false, hfdmdefines.ERR_USE_SKILL.GIVE_UP, false
    -- end
    return true, 0, true
end

function CHuodongSkill:DoUse(iTarget)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iOwner)
    if not oPlayer then return end
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then return end
    super(CHuodongSkill).DoUse(self, iTarget)
    local oHuodong = GetHuodong()
    local oState = oHuodong.m_oSkillMgr:AddShield(oTarget, self.m_iEffectLasts)
    if oState then
        oPlayer:NotifyMessage(global.oToolMgr:FormatColorString(GetTextData(3013), {SS = self.m_iEffectLasts}))
    end
end

function CHuodongSkill:NotifySkillErr(oPlayer, iErr)
    super(CHuodongSkill).NotifySkillErr(self, oPlayer, iErr)
end
