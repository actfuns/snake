-- 活动技能
local global = require "global"
local res = require "base.res"
local hfdmdefines = import(service_path("huodong.hfdm.defines"))

function GetTextData(iText)
    return global.oToolMgr:GetTextData(iText, {"huodong", "hfdm"})
end

function GetHuodong()
    return global.oHuodongMgr:GetHuodong("hfdm")
end

function NewHuodongSkill(iPid, iSkillId)
    local sPath = string.format("huodong/hfdm/skill/p%d", iSkillId)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("load hfdmhuodongskill err:%d", iSkillId))
    return oModule.NewSkill(iPid, iSkillId)
end

CHuodongSkillMgr = {}
CHuodongSkillMgr.__index = CHuodongSkillMgr
inherit(CHuodongSkillMgr, logic_base_cls())

function CHuodongSkillMgr:New(sHuodongName)
    local o = super(CHuodongSkillMgr).New(self)
    o:Init()
    o.m_sHuodongName = sHuodongName
    return o
end

function CHuodongSkillMgr:Init()
    self.m_mPlayerSkills = {}
    -- self.m_mShield = {}
end

function CHuodongSkillMgr:TouchPlayer(iPid)
    local mSkills = table_get_set_depth(self.m_mPlayerSkills, {iPid})
    if next(mSkills) then
        return
    end
    local oHuodong = GetHuodong()
    local mConfigs = oHuodong:GetSkillConfig()
    for iSkillId, mConfig in pairs(mConfigs) do
        if not mSkills[iSkillId] then
            mSkills[iSkillId] = NewHuodongSkill(iPid, iSkillId)
        end
    end
end

function CHuodongSkillMgr:PackSkillInfo(iPid)
    local mSkills = self.m_mPlayerSkills[iPid]
    if not mSkills then
        return {}
    end
    local mNet = {}
    for iSkillId, oSkill in pairs(mSkills) do
        table.insert(mNet, oSkill:PackInfo())
    end
    return mNet
end

function CHuodongSkillMgr:ClearAll()
    for iPid, mSkills in pairs(self.m_mPlayerSkills) do
        for iSkillId, oSkill in pairs(mSkills) do
            baseobj_delay_release(oSkill)
        end
    end
    self.m_mPlayerSkills = {}
    -- self.m_mShield = {}
end

function CHuodongSkillMgr:TryUseSkill(oPlayer, iSkillId, iTarget)
    local iPid = oPlayer:GetPid()
    local oSkill = table_get_depth(self.m_mPlayerSkills, {iPid, iSkillId})
    if not oSkill then
        return false, hfdmdefines.ERR_USE_SKILL.NO_SKILL, true
    end
    local bSucc, iErr, bResync = oSkill:CanUse(iTarget)
    if not bSucc then
        oSkill:NotifySkillErr(oPlayer, iErr)
        return bSucc, iErr, bResync
    end
    oSkill:DoUse(iTarget)
    return true, 0, true
end

-- 可以通过state来实现，写新的stateobj，注意要开启心跳主动超时，要注册到aoistate里，前端根据aoi展示护盾特效
function CHuodongSkillMgr:AddShield(oPlayer, iSec)
    -- self.m_mShield[iPid] = get_time() + iSec
    return oPlayer.m_oStateCtrl:AddState(hfdmdefines.STATE_ID.SHIELD, {time = iSec}, true)
    -- if self:GetTimeCb("CheckShield") then return end
    -- self:CheckShield()
end

-- function CHuodongSkillMgr:ToCheckPlayerShield(oPlayer)
--     local iTimeout = self.m_mShield[iPid]
--     if iTimeout < get_time() then
--         self:RemoveShield(iPid)
--     end
-- end

-- function CHuodongSkillMgr:DoCheckShield()
--     local iNow = get_time()
--     for _, iPid in pairs(table_key_list(self.m_mShield)) do
--         local iTimeout = self.m_mShield[iPid]
--         if iTimeout < iNow then
--             self:RemoveShield(iPid)
--         end
--     end
-- end

-- function CHuodongSkillMgr:CheckShield()
--     self:DelTimeCb("CheckShield")
--     self:DoCheckShield()
--     if not next(self.m_mShield) then
--         return
--     end
--     self:AddTimeCb("CheckShield", 1000, function()
--         local oHuodong = GetHuodong()
--         if oHuodong.m_oSkillMgr then
--             oHuodong.m_oSkillMgr:CheckShield()
--         end
--     end)
-- end

function CHuodongSkillMgr:ShowShield(oPlayer)
    local oState = oPlayer.m_oStateCtrl:HasState(hfdmdefines.STATE_ID.SHIELD)
    if not oState then
        return
    end
    oState:SetHide(false)
    oPlayer.m_oStateCtrl:RefreshMapFlag()
end

function CHuodongSkillMgr:HideShield(oPlayer)
    local oState = oPlayer.m_oStateCtrl:HasState(hfdmdefines.STATE_ID.SHIELD)
    if not oState then
        return
    end
    oState:SetHide(true)
    oPlayer.m_oStateCtrl:RefreshMapFlag()
end

function CHuodongSkillMgr:RemoveShield(oPlayer)
    -- self.m_mShield[iPid] = nil
    -- 刷新角色特效
    -- local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    oPlayer.m_oStateCtrl:RemoveState(hfdmdefines.STATE_ID.SHIELD)
end

function CHuodongSkillMgr:IsInShield(oPlayer)
    -- return (self.m_mShield[iPid] or 0) >= get_time()
    return oPlayer.m_oStateCtrl:HasState(hfdmdefines.STATE_ID.SHIELD)
end

-- function CHuodongSkillMgr:IsInShield(iPid)
--     local oSkill = table_get_depth(self.m_mPlayerSkills, {iPid, SKILL_ID.SHIELD})
--     if not oSkill then
--         return false
--     end
--     return oSkill:IsInEffect(iPid)
-- end

--------------------------

CHuodongSkillBase = {}
CHuodongSkillBase.__index = CHuodongSkillBase
inherit(CHuodongSkillBase, logic_base_cls())

function CHuodongSkillBase:New(iPid, iSkillId)
    local o = super(CHuodongSkillBase).New(self)
    o:Init(iPid, iSkillId)
    return o
end

function CHuodongSkillBase:Init(iPid, iSkillId)
    local oHuodong = GetHuodong()
    local mConfig = oHuodong:GetSkillConfig(iSkillId)
    assert(mConfig, string.format("skill %d no config", iSkillId))
    self.m_iOwner = iPid
    self.m_iSid = iSkillId
    self.m_iCd = mConfig.cd or 0
    self.m_iEffectLasts = mConfig.effect_lasts or 0
    self.m_sName = mConfig.name
end

function CHuodongSkillBase:Name()
    return self.m_sName
end

function CHuodongSkillBase:AddEffect(iPid)
    self.m_mEffectLasts[iPid] = get_time() + self.m_iEffectLasts
end

function CHuodongSkillBase:IsInEffect(iPid)
    return (self.m_mEffectLasts[iPid] or 0) > get_time()
end

function CHuodongSkillBase:PackInfo()
    local mNet = {id = self.m_iSid}
    local iWaitCd = 0
    if self.m_iCd > 0 then
        iWaitCd = (self.m_iCdClearAt or 0) - get_time()
        if iWaitCd < 0 then
            iWaitCd = 0
        end
    end
    mNet.cd = iWaitCd
    return mNet
end

function CHuodongSkillBase:CanUse(iTarget)
    if (self.m_iCdClearAt or 0) > get_time() then
        return false, hfdmdefines.ERR_USE_SKILL.IN_CD, true
    end
    return true, 0, true
end

function CHuodongSkillBase:DoUse(iTarget)
    if self.m_iCd > 0 then
        self.m_iCdClearAt = self.m_iCd + get_time()
    end
end

function CHuodongSkillBase:ClearCd()
    self.m_iCdClearAt = 0
end

function CHuodongSkillBase:NotifySkillErr(oPlayer, iErr)
    local oHuodong = GetHuodong()
    oHuodong:NotifySkillErr(oPlayer, iErr, self:Name())
end
