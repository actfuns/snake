local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local res = require "base.res"
local net = require "base.net"
local extend = require "base.extend"
local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines")) 
local attrmgr = import(service_path("attrmgr"))
local loadskill = import(service_path("skill.loadskill"))


ARTIFACT_POS = 8

function NewSpirit(iSpirit, iPid)
    return CSpirit:New(iSpirit, iPid)
end


PropHelperFunc = {}
function PropHelperFunc.id(o)
    return o:GetArtifactId()
end

function PropHelperFunc.exp(o)
    return o:GetExp()
end

function PropHelperFunc.grade(o)
    return o:GetGrade()
end

function PropHelperFunc.strength_exp(o)
    return o:GetStrengthExp()
end

function PropHelperFunc.strength_lv(o)
    return o:GetStrengthLv()
end

function PropHelperFunc.max_hp(o)
    return o:GetAttrByKey("max_hp")
end

function PropHelperFunc.max_mp(o)
    return o:GetAttrByKey("max_mp")
end

function PropHelperFunc.phy_attack(o)
    return o:GetAttrByKey("phy_attack")
end

function PropHelperFunc.phy_defense(o)
    return o:GetAttrByKey("phy_defense")
end

function PropHelperFunc.phy_damage_add(o)
    return o:GetAttrByKey("phy_damage_add")
end

function PropHelperFunc.mag_attack(o)
    return o:GetAttrByKey("mag_attack")
end

function PropHelperFunc.mag_defense(o)
    return o:GetAttrByKey("mag_defense")
end

function PropHelperFunc.mag_damage_add(o)
    return o:GetAttrByKey("mag_damage_add")
end

function PropHelperFunc.cure_power(o)
    return o:GetAttrByKey("cure_power")
end

function PropHelperFunc.speed(o)
    return o:GetAttrByKey("speed")
end

function PropHelperFunc.seal_ratio(o)
    return o:GetAttrByKey("seal_ratio")
end

function PropHelperFunc.res_seal_ratio(o)
    return o:GetAttrByKey("res_seal_ratio")
end

function PropHelperFunc.phy_critical_ratio(o)
    return o:GetAttrByKey("phy_cirtical_ratio")
end

function PropHelperFunc.res_phy_critical_ratio(o)
    return o:GetAttrByKey("res_phy_critical_ratio")
end

function PropHelperFunc.mag_critical_ratio(o)
    return o:GetAttrByKey("mag_critical_ratio")
end

function PropHelperFunc.res_mag_critical_ratio(o)
    return o:GetAttrByKey("res_mag_critical_ratio")
end

function PropHelperFunc.score(o)
    return o:GetScoreCache()
end

function PropHelperFunc.fight_spirit(o)
    return o:GetFightSpirit()
end

function PropHelperFunc.follow_spirit(o)
    return o:GetFollowSpirit()
end

function PropHelperFunc.spirit_list(o)
    local lSpirit = {}
    for iSpirit, oSpirit in pairs(o.m_mSpirits) do
        local mUnit = oSpirit:PackNetInfo()
        table.insert(lSpirit, mUnit)
    end
    return lSpirit
end



CArtifactCtrl = {}
CArtifactCtrl.__index = CArtifactCtrl
inherit(CArtifactCtrl, datactrl.CDataCtrl)

function CArtifactCtrl:New(iPid)
    local o = super(CArtifactCtrl).New(self, {pid=iPid})
    o.m_iPid = iPid
    o:Init()
    return o
end

function CArtifactCtrl:Init()
    self.m_iGrade = 0
    self.m_iExp = 0
    self.m_iStrengthLv = 0
    self.m_iStrengthExp = 0
    self.m_iFightSpirit = 0
    self.m_iFollowSpirit = 0
    self.m_mSpirits = {}

    self.m_mBaseAttr = {}
    self.m_mStrengthAttr = {}
    self.m_mSpiritAttr = {}
end

function CArtifactCtrl:Release()
    for iSpirit, oSpirit in pairs(self.m_mSpirits) do
        baseobj_safe_release(oSpirit)
    end
    super(CArtifactCtrl).Release(self)
end

function CArtifactCtrl:Save()
    local mSave = {}
    mSave.grade = self.m_iGrade
    mSave.exp = self.m_iExp
    mSave.strength_lv = self.m_iStrengthLv
    mSave.strength_exp = self.m_iStrengthExp
    mSave.fight_spirit = self.m_iFightSpirit
    mSave.follow_spirit = self.m_iFollowSpirit
    mSave.spirits = {}
    for iSpirit, oSpirit in pairs(self.m_mSpirits) do
        table.insert(mSave.spirits, oSpirit:Save())
    end
    return mSave
end

function CArtifactCtrl:Load(m)
    if not m then return end

    self.m_iGrade = m.grade
    self.m_iExp = m.exp
    self.m_iStrengthLv = m.strength_lv
    self.m_iStrengthExp = m.strength_exp
    self.m_iFightSpirit = m.fight_spirit
    self.m_iFollowSpirit = m.follow_spirit
    for _, mSpirit in pairs(m.spirits) do
        local oSpirit = NewSpirit(mSpirit.spirit_id, self.m_iPid)
        oSpirit:Load(mSpirit)
        self.m_mSpirits[mSpirit.spirit_id] = oSpirit
    end
end

function CArtifactCtrl:CalApply(oPlayer, bReEnter)
    if self:GetArtifactId() then
        self:CalBaseAttr()
        self:CalStrengthAttr()
        self:CalSpiritAttr()
        self:SpiritSkillEffect()
        global.oScoreCache:Dirty(self.m_iPid, "artifactctrl")
    end
end

function CArtifactCtrl:CalBaseAttr()
    local iArtifact = self:GetArtifactId()
    if not iArtifact then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return end
   
    local mRefresh = {} 
    for sAttr, iVal in pairs(self.m_mBaseAttr) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, -iVal)
        mRefresh[sAttr] = 1
    end

    local mAttr = self:GetBaseAttr(iArtifact)
    local mEnv = {lv = self.m_iGrade}
    for sAttr, sVal in pairs(mAttr) do
        local iVal = formula_string(sVal, mEnv)
        oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, iVal)
        self.m_mBaseAttr[sAttr] = iVal
        mRefresh[sAttr] = 1
    end
    return mRefresh
end

function CArtifactCtrl:GetArtifactId()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        local oItem = oPlayer.m_oItemCtrl:GetItem(ARTIFACT_POS)
        if oItem then
            return oItem:SID()
        end
    end
end

function CArtifactCtrl:Name()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        local oItem = oPlayer.m_oItemCtrl:GetItem(ARTIFACT_POS)
        return oItem:Name()
    end
    return ""
end

function CArtifactCtrl:GetExp()
    return self.m_iExp
end

function CArtifactCtrl:GetGrade()
    return self.m_iGrade
end

function CArtifactCtrl:GetStrengthLv()
    return self.m_iStrengthLv
end

function CArtifactCtrl:GetStrengthExp()
    return self.m_iStrengthExp
end

function CArtifactCtrl:AddExp(iExp, sReason)
    assert(iExp > 0, sReason)
    self:Dirty()
    self.m_iExp = self.m_iExp + iExp
    local iOldGrade = self.m_iGrade
    local iGradeLimit = self:GetMaxGrade()

    for i = 1, 200 do
        local iNextExp = self:GetNeedExp()
        if not iNextExp or self.m_iExp < iNextExp then
            break
        end
        if not iGradeLimit or self.m_iGrade >= iGradeLimit then
            break
        end

        self.m_iExp = self.m_iExp - iNextExp
        self.m_iGrade = self.m_iGrade + 1
    end

    self:PropArtifactChange({exp=1, grade=1})

    if iOldGrade ~= self.m_iGrade then
        self:OnUpgradeArtifact()
        self:Notify(self.m_iPid, 1003, {item=self:Name(), level=self.m_iGrade})
    end

    local mLogData = self:LogData()
    mLogData.old_grade = iOldGrade
    mLogData.add_exp = iExp
    mLogData.now_exp = self.m_iExp
    mLogData.now_grade = self.m_iGrade
    mLogData.reason = sReason
    record.log_db("artifact", "add_exp", mLogData)
end

function CArtifactCtrl:OnUpgradeArtifact()
    local mRefresh = self:CalBaseAttr()
    global.oScoreCache:Dirty(self.m_iPid, "artifactctrl")
    mRefresh.score = 1
    self:PropArtifactChange(mRefresh, true)
end

function CArtifactCtrl:GetNeedExp(iGrade)
    iGrade = iGrade or self.m_iGrade + 1
    return res["daobiao"]["artifact"]["upgrade"][iGrade]
end

function CArtifactCtrl:GetMaxGrade()
    local mLimit = res["daobiao"]["artifact"]["upgrade_limit"]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    local iTargetLimit = 0
    if oPlayer then
        local iPlayerGrade = oPlayer:GetGrade()
        for iGrade, iLimit in pairs(mLimit) do
            if iPlayerGrade < iGrade then
                return iTargetLimit
            else
                iTargetLimit = iLimit
            end
        end
    end
    return iTargetLimit
end

function CArtifactCtrl:GetUpgradeUseExp(iGrade)
    iGrade = math.min(iGrade, self:GetMaxGrade())
    if self.m_iGrade >= iGrade then
        return 0
    end
    local iNeed = self:GetNeedExp() - self.m_iExp
    if iGrade - self.m_iGrade >= 2 then
        for i = self.m_iGrade+2, iGrade do
            iNeed = iNeed + self:GetNeedExp(i)
        end
    end
    return iNeed
end

function CArtifactCtrl:AddStrengthExp(iExp, sReason)
    assert(iExp > 0, sReason)
    self:Dirty()
    self.m_iStrengthExp = self.m_iStrengthExp + iExp
    local iOldGrade = self.m_iStrengthLv
    local iGradeLimit = self:GetMaxStrengthLv()

    for i = 1, 200 do
        local iNextExp = self:GetNeedStrengthExp()
        if not iNextExp or self.m_iStrengthExp < iNextExp then
            break
        end
        if not iGradeLimit or self.m_iStrengthLv >= iGradeLimit then
            break
        end

        self.m_iStrengthExp = self.m_iStrengthExp - iNextExp
        self.m_iStrengthLv = self.m_iStrengthLv + 1
    end

    self:PropArtifactChange({strength_exp=1, strength_lv=1})

    if iOldGrade ~= self.m_iStrengthLv then
        self:OnStrengthArtifact()
        self:Notify(self.m_iPid, 2004, {item=self:Name(), level=self.m_iStrengthLv})
    end

    local mLogData = self:LogData()
    mLogData.old_grade = iOldGrade
    mLogData.add_exp = iExp
    mLogData.now_exp = self.m_iStrengthExp
    mLogData.now_grade = self.m_iStrengthLv
    mLogData.reason = sReason
    record.log_db("artifact", "strength", mLogData)
end

function CArtifactCtrl:OnStrengthArtifact()
    global.oScoreCache:Dirty(self.m_iPid, "artifactctrl")
    local mRefresh = self:CalStrengthAttr()
    mRefresh.score = 1
    self:PropArtifactChange(mRefresh, true)
end

function CArtifactCtrl:CalStrengthAttr()
    local iArtifact = self:GetArtifactId()
    if not iArtifact then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    local mRefresh = {}
    for sAttr, iVal in pairs(self.m_mStrengthAttr) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, -iVal)
        self.m_mStrengthAttr[sAttr] = nil
        mRefresh[sAttr] = 1
    end

    local mEnv = {strength_lv = self.m_iStrengthLv, lv=self.m_iGrade}
    local mAttr = self:GetStrengthEffect(mEnv)

    for _, mInfo in ipairs(res["daobiao"]["point"]) do
        if not mAttr[mInfo.macro] then
            goto continue
        end
        for sKey, iRatio in pairs(mInfo) do
            if string.sub(sKey, -4, -1) == "_add" then
                local sAttr = string.sub(sKey, 1, -5)
                local iVal = mAttr[mInfo.macro] * iRatio
                if math.tointeger(iVal) ~= 0 then
                    oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, iVal)
                    self.m_mStrengthAttr[sAttr] = (self.m_mStrengthAttr[sAttr] or 0) + iVal
                    mRefresh[sAttr] = 1
                end
            end
        end
        mAttr[mInfo.macro] = nil
        ::continue::
    end
    for sAttr, iVal in pairs(mAttr) do
        if math.tointeger(iVal) ~= 0 then
            oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, iVal)
            self.m_mStrengthAttr[sAttr] = iVal
            mRefresh[sAttr] = 1
        end
    end
    return mRefresh
end

function CArtifactCtrl:GetMaxStrengthLv()
    local mStrengthLimit = res["daobiao"]["artifact"]["strength_limit"]
    local iTargetLimit = 0
    for _, mLimit in ipairs(mStrengthLimit) do
        if self.m_iGrade < mLimit.equip_grade then
            return iTargetLimit
        else
            iTargetLimit = mLimit.strength_lv_limit
        end
    end
    return iTargetLimit
end

function CArtifactCtrl:GetNeedStrengthExp()
    local iGrade = iGrade or self.m_iStrengthLv + 1
    return res["daobiao"]["artifact"]["strength"][iGrade]
end

function CArtifactCtrl:GetStrengthUpgradeUseExp(iGrade)
    iGrade = math.min(iGrade, self:GetMaxStrengthLv())
    if self.m_iStrengthLv >= iGrade then
        return 0
    end
    local iNeed = self:GetNeedStrengthExp() - self.m_iStrengthExp
    if iGrade - self.m_iStrengthLv >= 2 then
        for i = self.m_iStrengthLv+2, iGrade do
            iNeed = iNeed + self:GetNeedStrengthExp(i)
        end
    end
    return iNeed
end

function CArtifactCtrl:GetSpiritById(iSpirit)
    return self.m_mSpirits[iSpirit]
end

function CArtifactCtrl:AddArtifactSpirit(iSpirit)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    local oSpirit = NewSpirit(iSpirit, self.m_iPid)
    oSpirit:InitSkill()
    self.m_mSpirits[iSpirit] = oSpirit
    self:Dirty()
    self:OnAddArtifactSpirit(iSpirit)

    local mLogData = self:LogData()
    mLogData.wakeup_spirit = iSpirit
    mLogData.skill = table.concat(table_key_list(oSpirit.m_mSkill), "|")
    record.log_db("artifact", "wakeup_spirit", mLogData)
end

function CArtifactCtrl:OnAddArtifactSpirit(iSpirit)
    self:RefreshOneSpirit(iSpirit)

    if table_count(self.m_mSpirits) == 1 then
        self:SetFollowSpirit(iSpirit)
        self:SetFightSpirit(iSpirit)
    end
end

function CArtifactCtrl:SetFollowSpirit(iSpirit)
    self:Dirty()
    self.m_iFollowSpirit = iSpirit

    self:PropArtifactChange({follow_spirit=1})
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)
    oPlayer:SyncModelInfo()

    local mLogData = self:LogData()
    mLogData.follow_spirit = iSpirit
    record.log_db("artifact", "follow_spirit", mLogData)
end

function CArtifactCtrl:GetFollowSpirit()
    return self.m_iFollowSpirit
end

function CArtifactCtrl:SetFightSpirit(iSpirit)
    self:Dirty()
    local iOldFight = self.m_iFightSpirit
    self.m_iFightSpirit = iSpirit
    self:PropArtifactChange({fight_spirit=1})
    self:OnSetFightSpirit(iOldFight, iSpirit)

    local mLogData = self:LogData()
    mLogData.fight_spirit = iSpirit
    record.log_db("artifact", "fight_spirit", mLogData)
end

function CArtifactCtrl:OnSetFightSpirit(iOldSpirit, iNewSpirit)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    if iOldSpirit and iOldSpirit > 0 then
        local oSpirit = self:GetSpiritById(iOldSpirit)
        for iSkill, oSkill in pairs(oSpirit.m_mSkill) do
            oSkill:SkillUnEffect(oPlayer)
        end
    end
    if iNewSpirit and iNewSpirit > 0 then
        local oSpirit = self:GetSpiritById(iNewSpirit)
        for iSkill, oSkill in pairs(oSpirit.m_mSkill) do
            oSkill:SkillEffect(oPlayer)
        end
    end

    global.oScoreCache:Dirty(self.m_iPid, "artifactctrl")
    local mRefresh = {score = 1}
    table_combine(mRefresh, self:CalSpiritAttr())
    self:PropArtifactChange(mRefresh, true)
end

function CArtifactCtrl:GetFightSpirit()
    return self.m_iFightSpirit
end

function CArtifactCtrl:CalSpiritAttr()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    local mRefresh = {}
    for sAttr, iVal in pairs(self.m_mSpiritAttr) do
        oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, -iVal)
        self.m_mSpiritAttr[sAttr] = nil
        mRefresh[sAttr] = 1
    end

    if self.m_iFightSpirit and self.m_iFightSpirit > 0 then
        local oSpirit = self:GetSpiritById(self.m_iFightSpirit)
        for sAttr, iVal in pairs(oSpirit:GetSpiritEffect()) do
            oPlayer.m_oEquipMgr:AddApply(sAttr, ARTIFACT_POS, iVal)
            self.m_mSpiritAttr[sAttr] = iVal
            mRefresh[sAttr] = 1
        end
    end
    return mRefresh
end

function CArtifactCtrl:ResetSkill(iSpirit)
    self:Dirty()
    local oSpirit = self:GetSpiritById(iSpirit)
    local iNum = oSpirit:GetSkillNumLimit()
    oSpirit.m_mBakSkill = oSpirit:ChooseSkill(iNum)

    self:RefreshOneSpirit(iSpirit)

    local mLogData = self:LogData()
    mLogData.spirit = iSpirit
    mLogData.skill = table.concat(table_key_list(oSpirit.m_mSkill), "|")
    mLogData.bak_skill = table.concat(table_key_list(oSpirit.m_mBakSkill), "|")
    record.log_db("artifact", "skill", mLogData)
end

function CArtifactCtrl:SaveSkill(iSpirit)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    self:Dirty()
    local oSpirit = self:GetSpiritById(iSpirit)

    for iSkill, oSkill in pairs(oSpirit.m_mSkill) do
        oSkill:SkillUnEffect(oPlayer)
    end
    oSpirit.m_mSkill = {}

    local mEffect = {}
    local mConfilict = res["daobiao"]["skill"]["skill_confilict"]
    for iSkill, _ in pairs(oSpirit.m_mBakSkill) do
        local oSkill = loadskill.NewSkill(iSkill)
        oSpirit.m_mSkill[iSkill] = oSkill

        if not mEffect[iSkill] then
            mEffect[iSkill] = 1
        end
        local lConfilict = table_get_depth(mConfilict, {iSkill, "confilict_list"}) or {}
        for _, iSkill in ipairs(lConfilict) do
            mEffect[iSkill] = 0
        end
    end
    for iSkill, iVal in pairs(mEffect) do
        local oSkill = oSpirit.m_mSkill[iSkill]
        if oSkill then
            oSkill:SkillUnEffect(oPlayer)
            if iVal == 1 then
                oSkill:SkillEffect(oPlayer)
            end
        end
    end

    oSpirit.m_mBakSkill = {}

    self:RefreshOneSpirit(iSpirit)
    global.oScoreCache:Dirty(self.m_iPid, "artifactctrl")
    self:PropArtifactChange({score=1}, true)

    local mLogData = self:LogData()
    mLogData.spirit = iSpirit
    mLogData.skill = table.concat(table_key_list(oSpirit.m_mSkill), "|")
    mLogData.bak_skill = ""
    record.log_db("artifact", "skill", mLogData)
end

function CArtifactCtrl:SpiritSkillEffect()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    if not self.m_iFightSpirit or self.m_iFightSpirit <= 0 then
        return 
    end

    local oSpirit = self:GetSpiritById(self.m_iFightSpirit)
    if not oSpirit then return end

    local mConfilict = res["daobiao"]["skill"]["skill_confilict"]
    local mEffect = {}
    for iSkill, oSkill in pairs(oSpirit.m_mSkill) do
        if not mEffect[iSkill] then
            mEffect[iSkill] = 1
        end
        local lConfilict = table_get_depth(mConfilict, {iSkill, "confilict_list"}) or {}
        for _, iSkill in ipairs(lConfilict) do
            mEffect[iSkill] = 0
        end
    end
    for iSkill, iVal in pairs(mEffect) do
        local oSkill = oSpirit.m_mSkill[iSkill]
        if oSkill then
            oSkill:SkillUnEffect(oPlayer)
            if iVal == 1 then
                oSkill:SkillEffect(oPlayer)
            end
        end
    end
end

function CArtifactCtrl:GetSpiritSkill(iSpirit)
    iSpirit = iSpirit or self.m_iFightSpirit
    local oSpirit = self:GetSpiritById(iSpirit)
    return oSpirit and oSpirit.m_mSkill or {}
end

function CArtifactCtrl:GetSpiritSkillNum(iSpirit)
    local mSkill = self:GetSpiritSkill(iSpirit)
    return table_count(mSkill)
end

function CArtifactCtrl:GetAttrByKey(sAttr)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return 0 end

    return oPlayer.m_oEquipMgr:GetApplyBySource(sAttr, ARTIFACT_POS)
end

function CArtifactCtrl:RefreshOneSpirit(iSpirit)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    local oSpirit = self:GetSpiritById(iSpirit)
    if oPlayer and oSpirit then
        oPlayer:Send("GS2CRefreshOneSpiritInfo", {spirit=oSpirit:PackNetInfo()})
    end
end

function CArtifactCtrl:GetScoreCache()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    return global.oScoreCache:GetScoreByKey(oPlayer, "artifactctrl")
end

function CArtifactCtrl:GetScore()
    local iSid = self:GetArtifactId()
    if not iSid then return 0 end

    local sScore = table_get_depth(res, {"daobiao", "artifact", "equip_score", iSid})
    if not sScore then return 0 end

    local mEnv = {
        lv = self.m_iGrade,
        strength_lv = self.m_iStrengthLv,
        fight_spirit_skill_num = self:GetSpiritSkillNum(),
        fight_spirit_lv = 0,
    }
    return formula_string(sScore, mEnv)
end

function CArtifactCtrl:PackArtifactNetInfo(mRefresh)
    mRefresh = mRefresh or PropHelperFunc
    local mRet = {}
    for k,v in pairs(mRefresh) do
        local f = assert(PropHelperFunc[k], string.format("artifact fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("Artifact", mRet)
end

function CArtifactCtrl:PropArtifactChange(mRefresh, bSyncPlayer)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if not oPlayer then return end

    local mNet = self:PackArtifactNetInfo(mRefresh)
    oPlayer:Send("GS2CRefreshArtifactInfo",{info=mNet})

    if bSyncPlayer and mRefresh and next(mRefresh) then
        if mRefresh.max_hp or mRefresh.max_mp then
            oPlayer:CheckAttr(true)
        end
        mRefresh.phy_damage_add = nil
        mRefresh.mag_damage_add = nil
        local lKey = table_key_list(mRefresh)
        oPlayer:PropChange(table.unpack(lKey))
    end
end

function CArtifactCtrl:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"artifact"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CArtifactCtrl:GetBaseAttr(iSid)
    iSid = iSid or self:GetArtifactId()
    return table_get_depth(res, {"daobiao", "artifact", "equip_attr", iSid})
end

function CArtifactCtrl:GetStrengthEffect(mEnv)
    local iArtifact = self:GetArtifactId()
    local mEffect = res["daobiao"]["artifact"]["strength_effect"][iArtifact]
    local mResult = {}
    for sKey, sVal in pairs(mEffect) do
        mResult[sKey] = formula_string(sVal, mEnv or {})
    end
    return mResult
end

function CArtifactCtrl:LogData()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    if oPlayer then
        return oPlayer:LogData()
    end
    return {pid = self.m_iPid}
end

function CArtifactCtrl:OnUpGrade(oPlayer, iFromGrade)
    global.oArtifactMgr:TryGetArtifact(oPlayer)
end


CSpirit = {}
CSpirit.__index = CSpirit
inherit(CSpirit, datactrl.CDataCtrl)

function CSpirit:New(iSpirit, iPid, iSchool)
    local o = super(CSpirit).New(self)
    o.m_iSpirit = iSpirit
    o.m_iPid = iPid
    o.m_iGrade = 0
    o.m_mSkill = {}
    o.m_mBakSkill = {}
    return o
end

function CSpirit:Release()
    for iSkill, oSkill in pairs(self.m_mSkill) do
        baseobj_safe_release(oSkill)
    end
    super(CSpirit).Release(self)
end

function CSpirit:Save()
    local mSave = {}
    mSave.spirit_id = self.m_iSpirit
    mSave.skill = table_key_list(self.m_mSkill)
    mSave.bak_skill = table_key_list(self.m_mBakSkill)
    mSave.grade = self.m_iGrade
    return mSave
end

function CSpirit:Load(m)
    if not m then return end

    self.m_iSpirit = m.spirit_id
    self.m_iGrade = m.grade
    for _, iSkill in ipairs(m.skill or {}) do
        self.m_mSkill[iSkill] = loadskill.NewSkill(iSkill)
    end
    for _, iSkill in ipairs(m.bak_skill or {}) do
        self.m_mBakSkill[iSkill] = 1
    end
end

function CSpirit:Dirty()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)
    oPlayer.m_oArtifactCtrl:Dirty()
end

function CSpirit:InitSkill()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
    assert(oPlayer)

    self:Dirty()
    local iNum = self:GetSkillNumLimit()
    local mSkill = self:ChooseSkill(iNum)
    for iSkill, _ in pairs(mSkill) do
        local oSkill = loadskill.NewSkill(iSkill)
        self.m_mSkill[iSkill] = oSkill
        oSkill:SkillEffect(oPlayer)
    end
end

function CSpirit:ChooseSkill(iNum)
    local lSkill, lPriority = {}, {}
    for iSkill, iPriority in pairs(self:GetSkillPriority()) do
        table.insert(lSkill, iSkill)
        table.insert(lPriority, iPriority)
    end
    local mSkill = {}
    for i = 1, 100 do
        if iNum <= 0 then break end

        local iIdx = extend.Random.random_list(lPriority)
        lPriority[iIdx] = 0
        mSkill[lSkill[iIdx]]= 1
        iNum = iNum - 1
    end
    return mSkill
end

function CSpirit:PackNetInfo()
    local mSpirit = {}
    mSpirit.spirit_id = self.m_iSpirit
    mSpirit.skill_list = table_key_list(self.m_mSkill)
    mSpirit.bak_skill_list = table_key_list(self.m_mBakSkill)
    local lAttr = {}
    for sKey, iVal in pairs(self:GetSpiritEffect()) do
        table.insert(lAttr, {attr = sKey, val = iVal})
    end
    mSpirit.attr_list = lAttr
    return mSpirit
end

function CSpirit:GetSchool()
    if not self.m_iSchool then
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
        if oPlayer then
            self.m_iSchool = oPlayer:GetSchool()
        end
    end
    return self.m_iSchool
end

function CSpirit:GetGrade()
    return self.m_iGrade
end

function CSpirit:GetSkillNumLimit()
    local mNum = res["daobiao"]["artifact"]["spirit_skill_num_priority"][self.m_iSpirit]
    return extend.Random.choosekey(mNum)
end

function CSpirit:GetSkillPriority()
    local iSchool = self:GetSchool()
    return res["daobiao"]["artifact"]["skill_priority"][iSchool]
end

function CSpirit:GetSpiritEffect(mEnv)
    local iSchool = self:GetSchool()
    local iSpirit = self.m_iSpirit
    local sEffect = res["daobiao"]["artifact"]["school_spirit_effect"][iSchool][iSpirit]
    return formula_string(sEffect, mEnv or {})
end

