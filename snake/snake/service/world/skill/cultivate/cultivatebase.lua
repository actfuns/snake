-- import module
local global = require "global"
local res = require "base.res"

local skillobj = import(service_path("skill/skillobj"))
local loadskill = import(service_path("skill/loadskill"))

CCultivateSkill = {}
CCultivateSkill.__index = CCultivateSkill
CCultivateSkill.m_sType = "cultivate"
inherit(CCultivateSkill, skillobj.CSkill)

function NewSkill(...)
    local o = CCultivateSkill:New(...)
    return o
end

function CCultivateSkill:New(iSk)
    local o = super(CCultivateSkill).New(self, iSk)
    o:SetData("level", 0)
    o:SetData("extra_level", 0)
    o:SetData("exp", 0)
    return o
end

function CCultivateSkill:Load(mData)
    super(CCultivateSkill).Load(self, mData)
    self:SetData("level", mData["level"] or 0)
    self:SetData("extra_level", mData["extra_level"] or 0)
    self:SetData("exp", mData["exp"] or 0)
end

function CCultivateSkill:Save()
    local mData = {}
    mData["level"] = self:GetData("level", 0)
    mData["exp"] = self:GetData("exp", 0)
    mData["extra_level"] = self:GetData("extra_level", 0)
    return mData
end

function CCultivateSkill:Type()
    return self.m_sType
end

function CCultivateSkill:EffectType()
    local mData =  self:GetSkillData()
    return mData.type
end

function CCultivateSkill:Name()
    local mData = self:GetSkillData()
    return mData.name
end

function CCultivateSkill:Level()
    return self:GetData("level") + self:GetData("extra_level")
end

function CCultivateSkill:Exp()
    return self:GetData("exp")
end

function CCultivateSkill:GetGradeLimitConfig(oPlayer)
    local iGrade = oPlayer:GetGrade()
    local lCultivatelevelList = res["daobiao"]["cultivatelevel"]
    local mCultivatelevel = nil
    for  index, mData in ipairs(lCultivatelevelList) do
        if iGrade < mData.grade then
            mCultivatelevel = lCultivatelevelList[index - 1]
            break
        end
    end
    if not mCultivatelevel then
        mCultivatelevel = lCultivatelevelList[#lCultivatelevelList]
    end
    return mCultivatelevel
end

function CCultivateSkill:MaxLevel(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local iServerGrade = oPlayer:GetServerGrade()
    local iGrade = oPlayer:GetGrade()

    local mCultivatelevel = self:GetGradeLimitConfig(oPlayer)
    local iMaxLevel = mCultivatelevel.upper_level
    
    local iHisOffer, iOrgLv = 0, 0 --帮贡
    local oOrg = oPlayer:GetOrg()
    if oOrg then
        iHisOffer = oOrg:GetHisOffer(oPlayer:GetPid()) or 0
        iOrgLv = oOrg:GetLevel()
    end

    local sFormula = mCultivatelevel["limit_lv1"]
    local iOfferMaxLevel = 0
    if iGrade > iServerGrade - 5 then
        sFormula = mCultivatelevel["limit_lv2"]
    end
    iOfferMaxLevel = formula_string(sFormula, {slv = iServerGrade, hisoffer = iHisOffer})

    local iLimit = 0
    local iOrgLimit = self:GetOrgLvLimit(iOrgLv)
    if iMaxLevel > iOrgLimit then
        iMaxLevel, iLimit = iOrgLimit, 2
    end

    if iMaxLevel > iOfferMaxLevel then
        iMaxLevel, iLimit = iOfferMaxLevel, 1
    end
    return math.min(math.floor(iMaxLevel), 20), iLimit
end

function CCultivateSkill:GetOrgLvLimit(iOrgLv)
    local mOrgLevel = res["daobiao"]["cultivateorglimit"]
    local mData = mOrgLevel[iOrgLv]
    if mData then return mData["upper_level"] end

    local iMax = math.max(table.unpack(table_key_list(mOrgLevel)))
    return mData[iMax]["upper_level"]
end

function CCultivateSkill:IsMaxLevel(oPlayer)
    local iCurLv = self:GetData("level") + self:GetData("extra_level")
    if iCurLv >= self:MaxLevel(oPlayer) then
        return true
    else
        return false
    end
end

function CCultivateSkill:AddExp(oPlayer, iAddExp)
    local iSk = self.m_ID
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iServerGrade = oPlayer:GetServerGrade()
    local iGrade = oPlayer:GetGrade()
    local mData = self:GetSkillData()
    local iExp = self:GetData("exp")
    if iGrade < iServerGrade - 5 then
        iAddExp = math.ceil(iAddExp * (1 + 0.3))
    end
    iExp = iExp + iAddExp
    local iLevel = self:GetData("level")
    local iOldLevel = iLevel
    local iUpperLevel = self:MaxLevel(oPlayer)
    if iLevel >= iUpperLevel then
        return
    end

    local iUpperExp = formula_string(mData.exp, {lv = iLevel + 1})
    while (iExp > iUpperExp) do
        iLevel = iLevel + 1
        iExp = iExp - iUpperExp
        if iLevel >= iUpperLevel then
            break
        end
        if iLevel < iUpperLevel then
            iUpperExp = formula_string(mData.exp, {lv = iLevel + 1})
        end
    end
    local iNewLevel =  iLevel
    self:SetData("level",iNewLevel)
    self:SetData("exp", iExp)
    local sMsg = string.format("你获得了#G%d#n点#R%s#n经验", iAddExp, self:Name())
    oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    self:GS2CRefreshSkill(oPlayer)
    global.oScoreCache:Dirty(oPlayer:GetPid(), "skill")
    if iOldLevel ~= iNewLevel then
        oPlayer:PropChange("score")
    end
    self:Dirty()
end

function CCultivateSkill:GS2CRefreshSkill(oPlayer)
    local mItemSid = {10007, 10008}
    local mItemUseInfo = {}
    for _, sid in pairs(mItemSid) do
        local oItem = global.oItemLoader:GetItem(sid)
        if oItem then
            local iLimit, iCountLimit = oItem:DayUseLimit(oPlayer)
            table.insert(mItemUseInfo, { itemsid = sid, count_limit = iCountLimit, flag_limit = iLimit})
        end
    end
    local mNet = {}
    mNet["skill_info"] = self:PackNetInfo()
    local iMaxLv, iLimit = self:MaxLevel(oPlayer)
    mNet["upperlevel"] = iMaxLv
    mNet["limit"] = iLimit
    mNet["item_useinfo"] = mItemUseInfo
    if oPlayer then
        oPlayer:Send("GS2CRefreshCultivateSkill", mNet)
    end
end

function CCultivateSkill:GS2CRefreshSkillMaxLevel(oPlayer)
    local mNet = {}
    local iMaxLv, iLimit = self:MaxLevel(oPlayer)
    mNet["upperlevel"] = iMaxLv
    mNet["limit"] = iLimit
    if oPlayer then
        oPlayer:Send("GS2CRefreshSkillMaxLevel", mNet)
    end
end

function CCultivateSkill:PackNetInfo()
    local mNet = {}
    mNet["sk"] = self.m_ID
    mNet["level"] = self:GetData("level")
    mNet["exp"] = self:GetData("exp")
    mNet["extra_level"] = self:GetData("extra_level")
    return mNet
end
