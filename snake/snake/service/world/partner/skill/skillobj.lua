--import module
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))

function NewSkill(iSk)
    return CSkill:New(iSk)
end


CSkill = {}
CSkill.__index = CSkill
inherit(CSkill, datactrl.CDataCtrl)

function CSkill:New(iSk)
    local o = super(CSkill).New(self)
    o.m_ID = iSk
    o:Init()
    return o
end

function CSkill:Init()
    self:SetData("level", 1)
    self.m_mApply = {}
    self.m_mOwnerApply = {}
end

function CSkill:Save()
    local mData = {}
    mData["sk"] = self:GetID()
    mData["level"] = self:Level()
    return mData
end

function CSkill:Load(mData)
    self:SetData("level", mData.level)
end

function CSkill:GetID()
    return self.m_ID
end

function CSkill:GetSkillInfo()
    local mData = res["daobiao"]["partner"]["skill"][self.m_ID]
    assert(mData, string.format("partner skill err: %d skill id not exist", self:GetID() ))
    return mData
end

function CSkill:Name()
    local mInfo = self:GetSkillInfo()
    return mInfo["name"]
end

function CSkill:Level()
    return self:GetData("level")
end

function CSkill:SetLevel(iLevel)
    if 0 > iLevel then 
        return
    end
    
    self:SetData("level", iLevel)
end

function CSkill:Type()
    local mInfo = self:GetSkillInfo()
    return mInfo["type"]
end

function CSkill:ProtectType()
    local mInfo = self:GetSkillInfo()
    return mInfo["protect"]
end

function CSkill:LimitLevel()
    return 5
end

function  CSkill:LimitProtectLevel()
    return 5
end

function CSkill:GetPerformList()
    local mInfo = self:GetSkillInfo()
    local mPfData = mInfo["pflist"] or {}
    local mPerform = {}
    for _, iPerform in ipairs(mPfData) do
        mPerform[iPerform] = self:Level()
    end
    return mPerform
end

function CSkill:SkillEffect(o)
    local iOwner = o:GetOwnerID()
    self:SkillUnEffect(iOwner)

    local mInfo = self:GetSkillInfo()
    local mEffectInfo = mInfo.skill_effect
    for _, sEffect in ipairs(mEffectInfo) do
        local sApply,sFormula = string.match(sEffect,"(.+)=(.+)")
        if sApply and sFormula then
            local iValue = formula_string(sFormula,{level=self:Level(), grade = o:GetGrade()})
            iValue = decimal(iValue)
            if self:ProtectType() == 0 then
                self:AddApply(sApply,iValue)
            else
                self:AddOwnerApply(sApply,iValue, iOwner)
            end
        end
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if oPlayer then
        local mRefresh = table_copy(self.m_mOwnerApply)
        oPlayer.m_oPartnerCtrl:RefreshPlayerProp(mRefresh)
    end
end

function CSkill:SkillUnEffect(iOwner)
    self.m_mApply = {}
    self.m_mOwnerApply = {}
    local mRefresh = table_copy(self.m_mOwnerApply)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if oPlayer then
        oPlayer.m_oPartnerCtrl:RefreshPlayerProp(mRefresh)
    end
end

function CSkill:AddApply(sApply,iValue)
    local iApply = self.m_mApply[sApply] or 0
    self.m_mApply[sApply] = iApply + iValue
end

function CSkill:GetApply(sApply,rDefault)
    rDefault = rDefault or 0
    return self.m_mApply[sApply] or rDefault
end

function CSkill:AddOwnerApply(sApply,iValue)
    local iApply = self.m_mOwnerApply[sApply] or 0
    self.m_mOwnerApply[sApply] = iApply + iValue
end

function CSkill:GetOwnerApply(sApply, rDefault)
    rDefault = rDefault or 0
    return self.m_mOwnerApply[sApply] or rDefault
end

function CSkill:GetAllOwnerApply()
    return self.m_mOwnerApply
end

function CSkill:LearnNeedCost(iLevel)
end

-- 获取技能升级信息
function CSkill:GetSkillUpgradeInfo()
    local iSid = self:GetID()
    local iLevel = self:Level()
    local mUpgradeInfo = res["daobiao"]["partner"]["skillupgrade"]
    local id= mUpgradeInfo.index[iSid][iLevel]
    assert(id, "skill upgrade error %d ,%d", iSid, iLevel)
    return mUpgradeInfo[id]
end

-- 检查升级
function CSkill:PreCheckUpgrade()
    local iProtectType = self:ProtectType()
    local iLevel = self:Level()

    -- 检查技能等级达到上限
    if iLevel >= self:LimitLevel() then
        return false
    end

    -- 护主技能必须小于最大等级
    if 1 == iProtectType then
        if  iLevel >= self:LimitProtectLevel() then
            return false
        end
    end  

    return true
end

function CSkill:Upgrade(oPartner)
    if not oPartner then
        return
    end

    local iLevel = self:Level() + 1
    self:SetLevel(iLevel)
    self:SkillEffect(oPartner)
    global.oScoreCache:Dirty(oPartner:GetInfo("pid"), "huzhu")
    global.oScoreCache:Dirty(oPartner:GetInfo("pid"), "partnerctrl")
    global.oScoreCache:PartnerDirty(oPartner:GetID())

    oPartner:PropChange("skill")
    oPartner:SecondLevelPropChange()
    oPartner:ThreeLevelPropChange()

    local iOwner = oPartner:GetOwnerID()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if oPlayer then
        oPlayer.m_oPartnerCtrl:FireUpgradeSkill(oPartner, self, iLevel)
        oPlayer:PropChange("score")
    end
end

function CSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self:GetID()
    mNet["level"] = self:Level()
    return mNet
end

function CSkill:GetScore()
    local mInfo = self:GetSkillInfo()
    local sFormula = mInfo["score"]
    local iValue = formula_string(sFormula, {lv = self:Level()})
    return iValue
end

