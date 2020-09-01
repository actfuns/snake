--import module
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local loadskill = import(service_path("skill.loadskill"))
local roplayer = import(service_path("rofighter.roplayer"))
local ropartner = import(service_path("rofighter.ropartner"))
local rosummon = import(service_path("rofighter.rosummon"))

local floor = math.floor

function NewRobot(...)
    return CRobot:New(...)
end


CRobot = {}
CRobot.__index = CRobot
inherit(CRobot,logic_base_cls())

function CRobot:New(idx, mData)
    local o = super(CRobot).New(self)
    o.m_iIdx = idx
    o:Init(mData)
    return o
end

function CRobot:Release()
    if self.m_oRoPlayer then
        baseobj_safe_release(self.m_oRoPlayer)
    end
    if self.m_oRoSummon then
        baseobj_safe_release(self.m_oRoSummon)
    end
    for _, oRoPartner in pairs(self.m_mRoPartners) do
        baseobj_safe_release(oRoPartner)
    end
    self.m_mRoPartners = {}
    super(CRobot).Release(self)
end

function CRobot:Init(mData)
    -- mData = self:FixGradeInfo(mData)
    self.m_sName = mData.name
    self.m_iGrade = mData.grade
    self.m_iSchool = mData.school
    self.m_iIcon = mData.icon
    self.m_mModelInfo = {
        shape = mData.shape,
        scale = 0,
        color = {0},
        mutate_texture = 0,
        weapon = mData.weapon,
        adorn = 0,
        fuhun = mData.fuhun,
    }
    if mData.score then
        self.m_iScore = mData.score
    end

    self:InitBaseScore(mData.ratio)
    local mFight = self:InitFightData(mData.ratio)
    local oRoPlayer = roplayer.NewRoPlayer(self.m_iIdx)
    oRoPlayer:Init(mFight)
    self.m_oRoPlayer = oRoPlayer

    local mSummon = self:InitSummonFightData(mData.summongrade, mData.summonsid)
    local oRoSummon = rosummon.NewRoSummon(self.m_iIdx, 1)
    oRoSummon:Init(mSummon)
    self.m_oRoSummon = oRoSummon

    self.m_lLineup = {}
    self.m_mRoPartners = {}
    for _, sid in pairs(mData.partners) do
        local mPartner = self:InitPartnerFightData(mData.partnergrade, sid)
        local oRoPartner = ropartner.NewRoPartner(sid)
        oRoPartner:Init(mPartner)
        self.m_mRoPartners[sid] = oRoPartner
        table.insert(self.m_lLineup, sid)
    end
end

function CRobot:InitBaseScore(iRatio)
    local mData = res["daobiao"]["jjc"]["robot_attr"][self.m_iSchool]
    assert(mData, string.format("robot init robot_attr err %d", self.m_iSchool))

    local mEnv = {grade=self.m_iGrade}
    self.m_iBaseScore = self:CalPropAttr(mData["score"], mEnv, iRatio)
end

function CRobot:InitFightData(ratio)
    local mData = res["daobiao"]["jjc"]["robot_attr"][self.m_iSchool]
    assert(mData, string.format("robot init robot_attr err %d", self.m_iSchool))

    local mFightData = {}
    mFightData.name = self.m_sName
    mFightData.grade = self.m_iGrade
    mFightData.school = self.m_iSchool
    mFightData.model_info = self.m_mModelInfo
    
    local mEnv = {grade=self.m_iGrade}
    mFightData.hp = self:CalPropAttr(mData["hp"], mEnv, iRatio)
    mFightData.max_hp = mFightData.hp
    mFightData.mp = self:CalPropAttr(mData["mp"], mEnv, iRatio)
    mFightData.max_mp = mFightData.mp

    mFightData.physique = self:CalPropAttr(mData["physique"], mEnv, iRatio)
    mFightData.magic = self:CalPropAttr(mData["magic"], mEnv, iRatio)
    mFightData.strength = self:CalPropAttr(mData["strength"], mEnv, iRatio)
    mFightData.endurance = self:CalPropAttr(mData["endurance"], mEnv, iRatio)
    mFightData.agility = self:CalPropAttr(mData["agility"], mEnv, iRatio)

    mFightData.cure_power = self:CalPropAttr(mData["cure_power"], mEnv, iRatio)
    mFightData.phy_attack = self:CalPropAttr(mData["phy_attack"], mEnv, iRatio)
    mFightData.mag_attack = self:CalPropAttr(mData["mag_attack"], mEnv, iRatio)
    mFightData.phy_defense = self:CalPropAttr(mData["phy_defense"], mEnv, iRatio)
    mFightData.mag_defense = self:CalPropAttr(mData["mag_defense"], mEnv, iRatio)
    mFightData.speed = self:CalPropAttr(mData["speed"], mEnv, iRatio)

    mFightData.phy_critical_ratio = self:CalPropAttr(mData["phy_critical_ratio"], mEnv, iRatio)
    mFightData.res_phy_critical_ratio = self:CalPropAttr(mData["res_phy_critical_ratio"], mEnv, iRatio)
    mFightData.mag_critical_ratio = self:CalPropAttr(mData["mag_critical_ratio"], mEnv, iRatio)
    mFightData.res_mag_critical_ratio = self:CalPropAttr(mData["res_mag_critical_ratio"], mEnv, iRatio)
    mFightData.seal_ratio = self:CalPropAttr(mData["seal_ratio"], mEnv, iRatio)
    mFightData.res_seal_ratio = self:CalPropAttr(mData["res_seal_ratio"], mEnv, iRatio)
    mFightData.phy_hit_ratio = self:CalPropAttr(mData["phy_hit_ratio"], mEnv, iRatio)
    mFightData.phy_hit_res_ratio = self:CalPropAttr(mData["phy_hit_res_ratio"], mEnv, iRatio)
    mFightData.mag_hit_ratio = self:CalPropAttr(mData["mag_hit_ratio"], mEnv, iRatio)
    mFightData.mag_hit_res_ratio = self:CalPropAttr(mData["mag_hit_res_ratio"], mEnv, iRatio)

    local mPerform = {}
    local lSkills = loadskill.GetActiveSkill(self.m_iSchool)
    for _, sk in ipairs(lSkills) do
        local mSkill = res["daobiao"]["skill"][sk]
        local mPfData, mLevel, iLv = mSkill["pflist"], mSkill["learn_limit"], 1
        for _, v in pairs(mLevel) do
            iLv = v.level
            if v.grade > self.m_iGrade then break end
        end
        for _,mData in pairs(mPfData) do
            mPerform[mData["pfid"]] = iLv
        end
    end
    mFightData.perform = mPerform
    local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("XIU_LIAN_SYS")
    if self:GetGrade() > iOpenLevel then
        self.m_mExpertSkillLV = math.min(10, math.floor((self:GetGrade()-30)/10))
    else
        self.m_mExpertSkillLV = 0
    end
    mFightData.expertskill = self:PackExpertSkill()
    return mFightData
end

function CRobot:InitPartnerFightData(grade, sid, iRatio)
    local mData = res["daobiao"]["jjc"]["partner_attr"][sid]
    assert(mData, string.format("robot init partner_attr err %d", sid))
    local mPartnerInfo = res["daobiao"]["partner"]["info"][sid]
    assert(mPartnerInfo, string.format("robot init partner err %d", sid))

    local mPartnerData = {}
    local mEnv = {grade = grade}
    mPartnerData.pid = sid
    mPartnerData.grade = grade
    mPartnerData.name = mPartnerInfo.name
    mPartnerData.school = mPartnerInfo.school
    mPartnerData.icon = mPartnerInfo.shape
    mPartnerData.score = self:CalPropAttr(mData["score"], mEnv, iRatio)
    mPartnerData.model_info = {
        shape = mPartnerInfo.shape,
        scale = 0,
        color = {0},
        mutate_texture = 0,
        weapon = 0,
        adorn = 0,
    }

    mPartnerData.hp = self:CalPropAttr(mData["hp"], mEnv, iRatio)
    mPartnerData.max_hp = mPartnerData.hp
    mPartnerData.mp = self:CalPropAttr(mData["mp"], mEnv, iRatio)
    mPartnerData.max_mp = mPartnerData.mp

    mPartnerData.physique = self:CalPropAttr(mData["physique"], mEnv, iRatio)
    mPartnerData.magic = self:CalPropAttr(mData["magic"], mEnv, iRatio)
    mPartnerData.strength = self:CalPropAttr(mData["strength"], mEnv, iRatio)
    mPartnerData.endurance = self:CalPropAttr(mData["endurance"], mEnv, iRatio)
    mPartnerData.agility = self:CalPropAttr(mData["agility"], mEnv, iRatio)

    mPartnerData.cure_power = self:CalPropAttr(mData["cure_power"], mEnv, iRatio)
    mPartnerData.phy_attack = self:CalPropAttr(mData["phy_attack"], mEnv, iRatio)
    mPartnerData.mag_attack = self:CalPropAttr(mData["mag_attack"], mEnv, iRatio)
    mPartnerData.phy_defense = self:CalPropAttr(mData["phy_defense"], mEnv, iRatio)
    mPartnerData.mag_defense = self:CalPropAttr(mData["mag_defense"], mEnv, iRatio)
    mPartnerData.speed = self:CalPropAttr(mData["speed"], mEnv, iRatio)

    mPartnerData.phy_critical_ratio = self:CalPropAttr(mData["phy_critical_ratio"], mEnv, iRatio)
    mPartnerData.res_phy_critical_ratio = self:CalPropAttr(mData["res_phy_critical_ratio"], mEnv, iRatio)
    mPartnerData.mag_critical_ratio = self:CalPropAttr(mData["mag_critical_ratio"], mEnv, iRatio)
    mPartnerData.res_mag_critical_ratio = self:CalPropAttr(mData["res_mag_critical_ratio"], mEnv, iRatio)
    mPartnerData.seal_ratio = self:CalPropAttr(mData["seal_ratio"], mEnv, iRatio)
    mPartnerData.res_seal_ratio = self:CalPropAttr(mData["res_seal_ratio"], mEnv, iRatio)
    mPartnerData.phy_hit_ratio = self:CalPropAttr(mData["phy_hit_ratio"], mEnv, iRatio)
    mPartnerData.phy_hit_res_ratio = self:CalPropAttr(mData["phy_hit_res_ratio"], mEnv, iRatio)
    mPartnerData.mag_hit_ratio = self:CalPropAttr(mData["mag_hit_ratio"], mEnv, iRatio)
    mPartnerData.mag_hit_res_ratio = self:CalPropAttr(mData["mag_hit_res_ratio"], mEnv, iRatio)

    local iQuality = 1
    for _, data in pairs(res["daobiao"]["partner"]["quality"]) do
        if grade > data["level"] then
            break
        end
        iQuality = data["id"]
    end
    local mUnlockSkill = res["daobiao"]["partner"]["skillunlock"]
    local mPerforms = {}
    for i, idx in ipairs(mUnlockSkill.index[sid]) do
        if i > grade  then
            break
        end
        for _, sk in pairs(mUnlockSkill[idx]["unlock_skill"]) do
            local iLevel = 1
            local mUpgradeInfo = res["daobiao"]["partner"]["skillupgrade"]
            if mUpgradeInfo.index[sk] then
                for lv, idx in ipairs(mUpgradeInfo.index[sk]) do
                    if mUpgradeInfo[idx]["partner_level"] > grade then
                        break
                    end
                    iLevel = mUpgradeInfo[idx]["level"]
                end
            end
            local mConfigPerform = table_get_depth(res["daobiao"], {"partner", "skill", sk, "pflist"})
            for _, iPerform in pairs(mConfigPerform or {}) do
                mPerforms[iPerform] = iLevel
            end
        end
    end
    mPartnerData.quality = iQuality
    mPartnerData.perform = mPerforms
    mPartnerData.expertskill = self:PackPartnerExpertSkill()
    return mPartnerData
end

function CRobot:InitSummonFightData(grade, sid, iRatio)
    local mData = res["daobiao"]["jjc"]["summon_attr"][sid]
    assert(mData, string.format("robot init summon_attr err %d", sid))
    local mSummonInfo = res["daobiao"]["summon"]["info"][sid]
    assert(mSummonInfo, string.format("robot init summon err %d", sid))

    local mSummonData = {}
    local mEnv = {grade = grade}
    mSummonData.pid = sid
    mSummonData.grade = grade
    mSummonData.name = mSummonInfo.name
    mSummonData.icon = mSummonInfo.shape
    mSummonData.score = self:CalPropAttr(mData["score"], mEnv, iRatio)
    mSummonData.model_info = {
        shape = mSummonInfo.shape,
        scale = 0,
        color = {0},
        mutate_texture = 0,
        weapon = 0,
        adorn = 0,
    }

    mSummonData.hp = self:CalPropAttr(mData["hp"], mEnv, iRatio)
    mSummonData.max_hp = mSummonData.hp
    mSummonData.mp = self:CalPropAttr(mData["mp"], mEnv, iRatio)
    mSummonData.max_mp = mSummonData.mp

    mSummonData.physique = self:CalPropAttr(mData["physique"], mEnv, iRatio)
    mSummonData.magic = self:CalPropAttr(mData["magic"], mEnv, iRatio)
    mSummonData.strength = self:CalPropAttr(mData["strength"], mEnv, iRatio)
    mSummonData.endurance = self:CalPropAttr(mData["endurance"], mEnv, iRatio)
    mSummonData.agility = self:CalPropAttr(mData["agility"], mEnv, iRatio)

    mSummonData.cure_power = self:CalPropAttr(mData["cure_power"], mEnv, iRatio)
    mSummonData.phy_attack = self:CalPropAttr(mData["phy_attack"], mEnv, iRatio)
    mSummonData.mag_attack = self:CalPropAttr(mData["mag_attack"], mEnv, iRatio)
    mSummonData.phy_defense = self:CalPropAttr(mData["phy_defense"], mEnv, iRatio)
    mSummonData.mag_defense = self:CalPropAttr(mData["mag_defense"], mEnv, iRatio)
    mSummonData.speed = self:CalPropAttr(mData["speed"], mEnv, iRatio)

    mSummonData.phy_critical_ratio = self:CalPropAttr(mData["phy_critical_ratio"], mEnv, iRatio)
    mSummonData.res_phy_critical_ratio = self:CalPropAttr(mData["res_phy_critical_ratio"], mEnv, iRatio)
    mSummonData.mag_critical_ratio = self:CalPropAttr(mData["mag_critical_ratio"], mEnv, iRatio)
    mSummonData.res_mag_critical_ratio = self:CalPropAttr(mData["res_mag_critical_ratio"], mEnv, iRatio)
    mSummonData.seal_ratio = self:CalPropAttr(mData["seal_ratio"], mEnv, iRatio)
    mSummonData.res_seal_ratio = self:CalPropAttr(mData["res_seal_ratio"], mEnv, iRatio)
    mSummonData.phy_hit_ratio = self:CalPropAttr(mData["phy_hit_ratio"], mEnv, iRatio)
    mSummonData.phy_hit_res_ratio = self:CalPropAttr(mData["phy_hit_res_ratio"], mEnv, iRatio)
    mSummonData.mag_hit_ratio = self:CalPropAttr(mData["mag_hit_ratio"], mEnv, iRatio)
    mSummonData.mag_hit_res_ratio = self:CalPropAttr(mData["mag_hit_res_ratio"], mEnv, iRatio)

    local mPerforms = {}
    for _, sk in pairs(mSummonInfo["talent"]) do
        for _, pf in pairs(res["daobiao"]["summon"]["skill"][sk]["pflist"]) do
            mPerforms[pf] = 1
        end
    end
    for _, sk in pairs(mSummonInfo["skill1"]) do
        for _, pf in pairs(res["daobiao"]["summon"]["skill"][sk]["pflist"]) do
            mPerforms[pf] = 1
        end
    end
    for _, sk in pairs(mSummonInfo["skill2"]) do
        for _, pf in pairs(res["daobiao"]["summon"]["skill"][sk]["pflist"]) do
            mPerforms[pf] = 1
        end
    end
    mSummonData.perform = mPerforms
    mSummonData.expertskill = self:PackPartnerExpertSkill()
    return mSummonData
end

function CRobot:PackExpertSkill()
    local lLevel = {}
    for i=1,4 do
        table.insert(lLevel, self.m_mExpertSkillLV)
    end
    return lLevel
end

function CRobot:PackPartnerExpertSkill()
    local lLevel = {}
    for i=1,4 do
        table.insert(lLevel, self.m_mExpertSkillLV)
    end
    return lLevel
end

function CRobot:GetPid()
    return self.m_iIdx
end

function CRobot:GetName()
    return self.m_sName
end

function CRobot:GetGrade()
    return self.m_iGrade
end

function CRobot:GetSchool()
    return self.m_iSchool
end

function CRobot:GetModelInfo()
    return self.m_mModelInfo
end

function CRobot:GetIcon()
    return self.m_iIcon
end

-- 评分
function CRobot:GetScore()
    if self.m_iScore then
        return self.m_iScore
    end
    
    local iValue
    local iScore = self.m_iBaseScore or 0
    local mRes = res["daobiao"]["rolebasicscore"]
    local mAttr = {"speed","mag_defense","phy_defense","mag_attack","phy_attack","max_hp", "max_mp"}
    for _, sAttr in ipairs(mAttr) do
        if mRes[sAttr] then
            local sFormula = mRes[sAttr]["command"]
            if self.m_oRoPlayer then
                iValue = decimal(formula_string(sFormula, {attr = self.m_oRoPlayer:GetAttr(sAttr)}))
                iScore = iScore + iValue
            end
        end
    end
    if self.m_oRoSummon then
        iScore = iScore + self.m_oRoSummon:GetScore()
    end

    for _, sid in ipairs(self.m_lLineup) do
        iScore = iScore + self.m_mRoPartners[sid]:GetScore()
    end
    return iScore
end

function CRobot:GetFormation()
    local iPid = self.m_iIdx
    local mResult = {}
    mResult.grade = 1
    mResult.fmt_id = 1
    mResult.pid = iPid
    mResult.player_list = {iPid}
    mResult.partner_list = self.m_lLineup
    return mResult
end

function CRobot:PackWarInfo()
    return self.m_oRoPlayer:PackWarInfo()
end

function CRobot:PacketSummonWarInfo()
    return self.m_oRoSummon:PackWarInfo()
end

function CRobot:PackPartnerWarInfo()
    local lWarInfo = {}
    for _, sid in ipairs(self.m_lLineup) do
        table.insert(lWarInfo, self.m_mRoPartners[sid]:PackWarInfo())
    end
    return lWarInfo
end

function CRobot:PacketLineupInfo()
    local mData = {}
    mData.fmtid, mData.fmtlv = 1, 1
    if self.m_oRoSummon then
        mData.summicon = self.m_oRoSummon:GetIcon()
        mData.summlv = self.m_oRoSummon:GetGrade()
    end

    local lPartners = {}
    for _, sid in ipairs(self.m_lLineup) do
        local mInfo = {}
        local oRoPartner = self.m_mRoPartners[sid]
        mInfo.icon = oRoPartner:GetIcon()
        mInfo.lv = oRoPartner:GetGrade()
        mInfo.quality = oRoPartner:GetQuality()
        table.insert(lPartners, mInfo)
    end
    mData.fighters = lPartners
    return mData
end

function CRobot:PackPartnerLineup()
    local lPartners = {}
    for _, sid in ipairs(self.m_lLineup) do
        local mInfo = {}
        local oRoPartner = self.m_mRoPartners[sid]
        mInfo.icon = oRoPartner:GetIcon()
        mInfo.lv = oRoPartner:GetGrade()
        mInfo.quality = oRoPartner:GetQuality()
        table.insert(lPartners, mInfo)
    end
    return lPartners
end

function CRobot:PackTargetInfo(iType, iRank)
    return {
        type = iType,
        id = self:GetPid(),
        rank = iRank,
        name = self:GetName(),
        score = self:GetScore(),
        model = self:GetModelInfo(),
        grade = self:GetGrade(),
        school = self:GetSchool(),
        fighters = self:PackPartnerLineup(),
    }
end

function CRobot:PacketWarKeepSummon()
    --战斗中 AI可召唤的召唤兽
    return {}
end

function CRobot:CalPropAttr(sFormula, mEnv, iRatio)
    iRatio = iRatio or 1
    local iValue = formula_string(sFormula, mEnv)
    return math.floor(iValue * iRatio)
end

function CRobot:GetAttrValue(mData, sAttr)
    local iRet = mData[sAttr] or 0
    local mPointAttr = {"speed","mag_defense","phy_defense","mag_attack","phy_attack"}
    if table_in_list(mPointAttr,sAttr) then
        local key = string.format("%s_add",sAttr)
        local m = res["daobiao"]["point"]
        for k, v in pairs(m) do
            local base = mData[v.macro] or 0
            local i = base * v[key]
            if i then
                iRet = iRet + i
            end
        end
    end
    return math.floor(iRet)
end
