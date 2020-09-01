--import module

local global = require "global"
local skillobj = import(service_path("skill/skillobj"))
local record = require "public.record"

function NewSkill(iSk)
    local sPath = string.format("skill/org/s%d", iSk)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("NewSkill org err:%d", iSk))
    local oSk = oModule.NewSkill(iSk)
    return oSk
end


COrgSkill = {}
COrgSkill.__index = COrgSkill
COrgSkill.m_sType = "org"
inherit(COrgSkill,skillobj.CSkill)

function COrgSkill:New(iSk)
    local o = super(COrgSkill).New(self, iSk)
    return o
end

function COrgSkill:Init()
    super(COrgSkill).Init(self)
    self.m_iLevel = self:GetSkillData()["init_lv"]
end

function COrgSkill:GetSkillData()
    local res = require "base.res"
    local mData = res["daobiao"]["orgskill"]["skill"]
    return mData[self.m_ID]
end

function COrgSkill:LearnNeedCost(iLv)
    return 0, 0, 0
end

function COrgSkill:GetCostEnergy()
    local sFormula = self:GetSkillData()["cost_energy"]
    return math.floor(formula_string(sFormula, {level=self:Level()}))
end

function COrgSkill:Use(oPlayer, mArgs)
end

function COrgSkill:Learn(oPlayer)
    if self:Level() >= self:LimitLevel(oPlayer) then return end

    local iSilver, iOffer, iPoint = self:LearnNeedCost(self:Level() + 1)
    iPoint = iPoint or 0
    if iSilver <= 0 and iOffer <= 0 and iPoint <= 0 then
        record.warning("orgskill learn error not cost")
        return
    end

    if iSilver > 0 and not oPlayer:ValidSilver(iSilver) then return end
    if iOffer > 0 and oPlayer:GetOffer() < iOffer then return end
    if iPoint > 0 and not oPlayer.m_oActiveCtrl:ValidStoryPoint(iPoint) then return end

    if iSilver > 0 then
        oPlayer:ResumeSilver(iSilver, "帮派技能升级")
    end
    if iOffer > 0 then
        oPlayer:AddOrgOffer(-iOffer, "帮派技能升级")
    end
    if iPoint and iPoint > 0 then
        oPlayer.m_oActiveCtrl:ResumeStoryPoint(iPoint, "帮派技能升级") 
    end

    local iOldLv = self:Level()
    local iNewLv = iOldLv + 1
    if iOldLv ~= iNewLv then
        oPlayer:PropChange("score")
    end
    self:SetLevel(iNewLv)
    global.oScoreCache:Dirty(oPlayer:GetPid(), "skill")
    self:SkillEffect(oPlayer)
    oPlayer:Send("GS2COrgSkills", {org_skill={self:PackNetInfo()}})
    self:Dirty()
    oPlayer.m_oSkillCtrl:FireLearnOrgSkill(self, iNewLv, iOldLv)
    oPlayer:MarkGrow(12)
end

function COrgSkill:EffectLevel()
    return self:GetSkillData()["effect_lv"]
end

function COrgSkill:MaxLevel()
    return self:GetSkillData()["max_lv"]
end

function COrgSkill:SkillEffect(oPlayer)
    if self:Level() <= 0 then return end

    self:SkillUnEffect(oPlayer)
    local mEffect = self:GetSkillData()["skill_effect"] or {}
    for _,sEffect in ipairs(mEffect) do
        local sApply, sFormula = string.match(sEffect,"(.+)=(.+)")
        if not sApply or not sFormula then break end

        local iValue = math.floor(formula_string(sFormula, {level=self:Level()}))
        oPlayer.m_oSkillMgr:AddApply(sApply, self.m_ID, iValue)
        self:AddApply(sApply, iValue)
        oPlayer:CheckAttr()
        oPlayer:AttrPropChange(sApply)
    end
end

function COrgSkill:SkillUnEffect(oPlayer)
    for sApply,iValue in pairs(self.m_mApply) do
        oPlayer.m_oSkillMgr:AddApply(sApply,self.m_ID, -iValue)
        oPlayer:AttrPropChange(sApply)
    end
    self.m_mApply = {}
end

function COrgSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:Level()
    return mNet
end
