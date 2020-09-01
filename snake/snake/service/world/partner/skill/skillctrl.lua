-- import module
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local loadskill = import(service_path("partner.skill.loadskill"))

function NewSkillCtrl(iPartner, iPid)
    return CSkillCtrl:New(iPartner, iPid)
end

CSkillCtrl = {}
CSkillCtrl.__index = CSkillCtrl
inherit(CSkillCtrl, datactrl.CDataCtrl)

function CSkillCtrl:New(iPartner, iPid)
    local o = super(CSkillCtrl).New(self, {partner = iPartner, pid=iPid})
    o.m_List = {}
    o.m_mProtectSkill = {}
    return o
end

function CSkillCtrl:Release()
    for iSk, oSk in pairs(self.m_List) do
        baseobj_safe_release(oSk)
    end
    self.m_List = {}
    self.m_mProtectSkill = {}
    super(CSkillCtrl).Release(self)
end

function CSkillCtrl:Load(mData)
    mData = mData or {}
    for _, mSkill in ipairs(mData) do
        local iSk = mSkill["sk"]
        local oSk = loadskill.LoadSkill(mSkill)
        assert(oSk, "partner skill err: %d %d", iSk)
        self.m_List[iSk] = oSk
        if oSk:ProtectType() == 1 then
            self.m_mProtectSkill[iSk] = 1
        end
    end
end

function CSkillCtrl:Save()
    local mData = {}
    for iSk, oSk in pairs(self.m_List) do
        table.insert(mData, oSk:Save())
    end
    return mData
end

function CSkillCtrl:GetSkill(iSk)
    return self.m_List[iSk]
end

function CSkillCtrl:AddSkill(oSk)
    local iSk = oSk:GetID()
    if not self.m_List[iSk] then
        self.m_List[iSk] = oSk
        global.oScoreCache:Dirty(self:GetInfo("pid"), "partnerctrl")
        global.oScoreCache:PartnerDirty(self:GetInfo("partner"))
        self:RefreshScore()
    end
    if oSk:ProtectType() == 1 then
        self.m_mProtectSkill[iSk] = 1
        global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
    end
end

function CSkillCtrl:DelSkill(iSkill)
    local oSkill = self.m_List[iSkill]
    if oSkill then
        oSkill:SkillUnEffect(self:GetInfo("pid", 0))
        self.m_List[iSkill] = nil
        self.m_mProtectSkill[iSkill] = nil
        baseobj_delay_release(oSkill)
        global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
        global.oScoreCache:Dirty(self:GetInfo("pid"), "partnerctrl")
        global.oScoreCache:PartnerDirty(self:GetInfo("partner"))
        self:RefreshScore()
    end
    self:Dirty()
end

function CSkillCtrl:CalApply(oPartner)
    for iSk, oSk in pairs(self.m_List) do
        oSk:SkillEffect(oPartner)
    end
end

function CSkillCtrl:GetOwnerApply(sAttr)
    local iRet = 0
    for iSk, _ in pairs(self.m_mProtectSkill) do
        local oSk = self:GetSkill(iSk)
        iRet = iRet + oSk:GetOwnerApply(sAttr)
    end
    return iRet
end

function CSkillCtrl:GetAllOwnerApply()
    local mAllApply = {}
    for iSk, _ in pairs(self.m_mProtectSkill) do
        local oSk = self:GetSkill(iSk)
        for sKey, iVal in pairs(oSk:GetAllOwnerApply()) do
            if not mAllApply[sKey] then
                mAllApply[sKey] = iVal
            else
                mAllApply[sKey] = mAllApply[sKey] + iVal
            end
        end
        ::continue::
    end
    return mAllApply
end

function CSkillCtrl:GetApply(sAttr)
    local iRet = 0
    for iSk, oSk in pairs(self.m_List) do
        if not self.m_mProtectSkill[iSk] then
            iRet = iRet + oSk:GetApply(sAttr)
        end
    end
    return iRet
end

function CSkillCtrl:GetRatioApply(sAttr)
    return 0
end

function CSkillCtrl:GetPerform()
    local mPerform = {}
    for iSk, oSk in pairs(self.m_List) do
        local mPfList = oSk:GetPerformList()
        for iPf, iLevel in pairs(mPfList) do
            mPerform[iPf] = iLevel
        end
    end
    local mPfConflict = res["daobiao"]["pfconflict"]
    for _, mInfo in ipairs(mPfConflict) do
        if not mPerform[mInfo.pfid] then
            goto continue
        end
        for _, iPerform in ipairs(mInfo.pfid_list) do
            mPerform[iPerform] = nil
        end
        ::continue::
    end
    return mPerform
end

function CSkillCtrl:UpgradeProtectSkill(oPartner)
    for iSk, _ in pairs(self.m_mProtectSkill) do
        local oSk = self:GetSkill(iSk)
        local iLevel = oSk:Level()
        if  iLevel < oSk:LimitProtectLevel() then
            iLevel = iLevel + 1
            oSk:SetLevel(iLevel)
            oSk:SkillEffect(oPartner)
            self:RefreshScore()
        end
    end
    global.oScoreCache:Dirty(self:GetInfo("pid"), "huzhu")
end

function CSkillCtrl:UnDirty()
    super(CSkillCtrl).UnDirty(self)
    for iSk, oSk in pairs(self.m_List) do
        oSk:UnDirty()
    end
end

function CSkillCtrl:IsDirty()
    local bDirty = super(CSkillCtrl).IsDirty(self)
   if bDirty then
        return true
    end
    for _,oSk in pairs(self.m_List) do
        if oSk:IsDirty() then
            return true
        end
    end
    return false
end

function CSkillCtrl:PackNetInfo()
    local mNet = {}
    for iSk, oSk in pairs(self.m_List) do
        table.insert(mNet, oSk:PackNetInfo())
    end
    return mNet
end

function CSkillCtrl:GetScore()
    local iScore = 0
    for _,oSK in pairs(self.m_List) do
        if oSK:ProtectType() ==0 then
            iScore = iScore +oSK:GetScore()
        end
    end
    return iScore
end

function CSkillCtrl:GetScoreByHuZu()
    local iScore = 0
    for iSk,oSK in pairs(self.m_List) do
        if oSK:ProtectType() ==1 then
            iScore = iScore +oSK:GetScore()
        end
    end
    return iScore
end

function CSkillCtrl:RefreshScore()
    local pid = self:GetInfo("pid")
    local partner = self:GetInfo("partner")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and  partner then
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(partner)
        if oPartner then
            oPartner:PropChange("score")
            oPlayer:PropChange("score")
        end
    end
end
