--import module
local global = require "global"
local skynet = require "skynet"
local net = require "base.net"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

-- tips
local mTips = {"partner"}

local datactrl = import(lualib_path("public.datactrl"))
local skillmgr = import(service_path("skillmgr"))
local equipmgr = import(service_path("equipmgr"))
local loadskill = import(service_path("partner.skill.loadskill"))
local skillobj = import(service_path("partner.skill.skillobj"))
local skillctrl = import(service_path("partner.skill.skillctrl"))
local equipctrl = import(service_path("partner.partnerequip_new"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewPartner(...)
    return CPartner:New(...)
end

local function DispatchPartnerID()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:DispatchPartnerID()
end

PropHelperFunc = {}

function PropHelperFunc.id(oPartner)
    return oPartner:GetID()
end

function PropHelperFunc.sid(oPartner)
    return oPartner:GetSID()
end

function PropHelperFunc.quality(oPartner)
    return oPartner:GetData("quality")
end

function PropHelperFunc.grade(oPartner)
    return oPartner:GetGrade()
end

function PropHelperFunc.name(oPartner)
    return oPartner:GetName()
end

function PropHelperFunc.exp(oPartner)
    return oPartner:GetData("exp")
end

function PropHelperFunc.max_hp(oPartner)
    return oPartner:GetMaxHp()
end

function PropHelperFunc.max_mp(oPartner)
    return oPartner:GetMaxMp()
end

function PropHelperFunc.hp(oPartner)
    return oPartner:GetHp()
end

function PropHelperFunc.mp(oPartner)
    return oPartner:GetMp()
end

function PropHelperFunc.physique(oPartner)
    return oPartner:GetAttr("physique")
end

function PropHelperFunc.strength(oPartner)
    return oPartner:GetAttr("strength")
end

function PropHelperFunc.magic(oPartner)
    return oPartner:GetAttr("magic")
end

function PropHelperFunc.endurance(oPartner)
    return oPartner:GetAttr("endurance")
end

function PropHelperFunc.agility(oPartner)
    return oPartner:GetAttr("agility")
end

function PropHelperFunc.phy_attack(oPartner)
    return oPartner:GetPhyAttack()
end

function PropHelperFunc.phy_defense(oPartner)
    return oPartner:GetPhyDefense()
end

function PropHelperFunc.mag_attack(oPartner)
    return oPartner:GetMagAttack()
end

function PropHelperFunc.mag_defense(oPartner)
    return oPartner:GetMagDefense()
end

function PropHelperFunc.cure_power(oPartner)
    return oPartner:GetCurePower()
end

function PropHelperFunc.speed(oPartner)
    return oPartner:GetSpeed()
end

function PropHelperFunc.seal_ratio(oPartner)
    return oPartner:GetSealRatio()
end

function PropHelperFunc.res_seal_ratio(oPartner)
    return oPartner:GetResSealRatio()
end

function PropHelperFunc.phy_critical_ratio(oPartner)
    return oPartner:GetPhyCriticalRatio()
end

function PropHelperFunc.res_phy_critical_ratio(oPartner)
    return oPartner:GetResPhyCriticalRatio()
end

function PropHelperFunc.mag_critical_ratio(oPartner)
    return oPartner:GetMagCriticalRatio()
end

function PropHelperFunc.res_mag_critical_ratio(oPartner)
    return oPartner:GetResMagCriticalRatio()
end

function PropHelperFunc.school(oPartner)
    return oPartner:GetSchool()
end

function PropHelperFunc.upper(oPartner)
    return oPartner:GetData("upper")
end

function PropHelperFunc.type(oPartner)
    return oPartner:GetType()
end

function PropHelperFunc.race(oPartner)
    return oPartner:GetRace()
end

function PropHelperFunc.model_info(oPartner)
    return oPartner:GetModelInfo()
end

function PropHelperFunc.skill(oPartner)
    return oPartner.m_oSkillCtrl:PackNetInfo()
end

function PropHelperFunc.equipsid(oPartner)
    return oPartner.m_oEquipCtrl:PackNetInfo()
end

function PropHelperFunc.score(oPartner)
    return oPartner:GetScore()
end


CPartner = {}
CPartner.__index = CPartner
inherit(CPartner, datactrl.CDataCtrl)

function CPartner:New(sid, iPid)
    local o = super(CPartner).New(self)
    o.m_iID = DispatchPartnerID()
    o:SetData("sid", sid)
    o:SetInfo("pid", iPid)
    o:Init()
    return o
end

function CPartner:Init()
    local iPid = self:GetInfo("pid")
    local iSid = self:GetData("sid")
    self.m_oSkillCtrl = skillctrl.NewSkillCtrl(self:GetID(), iPid)
    self.m_oEquipCtrl = equipctrl.NewEquipCtrl(self:GetID(), iPid, iSid)
end

function CPartner:Create(...)
    local mInfo = self:GetInfoData()
    self:SetData("name", mInfo.name)
    self:SetData("quality", mInfo.quality)
    self:SetData("grade", 1)
    self:SetData("exp", 0)
    self:SetData("upper", 1)
    --skill
    self:UnlockInitSkill(1)
    self:InitPartnerEquip()
    self:Setup()
    self:FullStatus(true)
end

function CPartner:Release()
    baseobj_safe_release(self.m_oSkillCtrl)
    baseobj_safe_release(self.m_oEquipCtrl)
    super(CPartner).Release(self)
end

function CPartner:Load(mData)
    --todo
    self:SetData("sid", mData.sid)
    self:SetData("name", mData.name)
    self:SetData("quality", mData.quality)
    self:SetData("grade", mData.grade)
    self:SetData("exp", mData.exp)
    self:SetData("hp", mData.hp)
    self:SetData("mp", mData.mp)
    self:SetData("upper", mData.upper)
    self:SetData("model_info", mData.model_info)
    self:SetData("init_equip", mData.init_equip)

    self.m_oSkillCtrl:Load(mData.skdata)
    self.m_oEquipCtrl:Load(mData.eqdata)
    self:Setup()
end

function CPartner:Save()
    local mData = {}
    mData.sid = self:GetData("sid")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.exp = self:GetData("exp")
    mData.hp = self:GetData("hp")
    mData.mp = self:GetData("mp")
    mData.quality = self:GetData("quality")
    mData.upper = self:GetData("upper")
    mData.init_equip = self:GetData("init_equip")
    mData.skdata = self.m_oSkillCtrl:Save()
    mData.eqdata = self.m_oEquipCtrl:Save()
    return mData
end

function CPartner:IsDirty()
    local bDirty = super(CPartner).IsDirty(self)
    if bDirty then return true end

    if self.m_oSkillCtrl:IsDirty() then
        return true
    end
    
    if self.m_oEquipCtrl:IsDirty() then
        return true
    end
end

function CPartner:Setup()
    self:CalBaseAllProp()
    self:PropChange("score")
    self.m_oSkillCtrl:CalApply(self)
    self.m_oEquipCtrl:Setup()
end

function CPartner:FullStatus(bForce)
    local oWorldMgr = global.oWorldMgr
    local iOwner = self:GetOwnerID()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iOwner)

    if bForce or (oPlayer and oPlayer.m_oStateCtrl:GetBaoShiCount() > 0) then
        self:SetData("hp", self:GetMaxHp())
        self:SetData("mp", self:GetMaxMp())
    else
        local iHP = self:GetData("hp")
        if not iHP or iHP < 0 or iHP > self:GetMaxHp() then
            self:SetData("hp", self:GetMaxHp())
        end
        local iMP = self:GetData("mp")
        if not iMP or iMP < 0 or iMP > self:GetMaxMp() then
            self:SetData("mp", self:GetMaxMp())
        end
    end
    self:PropChange("max_hp", "hp", "max_mp", "mp")
end

function CPartner:CalBaseFirstProp()
--    local lFirstProp = {"agility", "strength", "magic", "endurance", "physique"}
--    local iGrade = self:GetData("grade")
--    local mPointData= self:GetPointData()
--    for _, sName in pairs(lFirstProp) do
--        self:SetData(sName, iGrade * mPointData[sName])
--    end
end

function CPartner:CalBaseThirdProp()
    local lThirdProp = {"seal_ratio", "res_seal_ratio", "phy_critical_ratio",
        "res_phy_critical_ratio", "mag_critical_ratio", "res_mag_critical_ratio",}
    local mProp = self:GetPropData()
    for _, sName in pairs(lThirdProp) do
        self:SetData(sName, mProp[sName])
    end
end

function CPartner:CalBaseAllProp()
    local mProp = self:GetPropData()
    for sKey, iVal in pairs(mProp) do
        if sKey == "grade" or sKey == "point" then
            goto continue
        end
        self:SetData(sKey, iVal)
        ::continue::
    end
end

function CPartner:UnlockInitSkill(iGrade)
    local mData = self:GetUnlockSkillInfo(iGrade)
    for _, iSk in ipairs(mData.unlock_skill or {}) do
        local oSk = loadskill.NewSkill(iSk)
        assert(oSk, string.format("partner skill err: %d", iSk))
        self.m_oSkillCtrl:AddSkill(oSk)
    end
    
    local iProtect = self:GetProtectSkill()
    if iProtect then
        local oSk = loadskill.NewSkill(iProtect)
        self.m_oSkillCtrl:AddSkill(oSk)
    end
end

function CPartner:InitPartnerEquip()
    if not global.oToolMgr:IsSysOpen("PARTNER_ZB") then
        return
    end
   
    if self:GetData("init_equip") then return end
    self:Dirty()
    self:SetData("init_equip", 1)
    local iSid = self:GetSID()
    local lEquipSid = res["daobiao"]["partner"]["partner2equipsid"][iSid]
    for iEquipSid, _ in pairs(lEquipSid) do
        self.m_oEquipCtrl:AddEquipByPos(self, iEquipSid)
    end
end

function CPartner:GetID()
    return self.m_iID
end

function CPartner:GetSID()
    return self:GetData("sid")
end

function CPartner:GetInfoData()
    local sid = self:GetData("sid")
    local mData = res["daobiao"]["partner"]["info"][sid]
    assert(mData, string.format("CPartner:GetInfoData partner info config no exist! id: %d ", sid))
    return mData
end

function CPartner:GetSwapSkillCost()
    local mInfo = self:GetInfoData()
    return mInfo.swap_cost
end

function CPartner:GetQualityData()
    local iQualiy = self:GetData("quality")
    local mData = res["daobiao"]["partner"]["quality"][iQualiy]
    assert(mData, string.format("CPartner:GetQualityData partner quality config no exist! id:", iQualiy))
    return mData
end

function CPartner:GetProtectSkill()
    local iPid = self:GetOwnerID()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iSchool = oPlayer:GetSchool()
    local iSid = self:GetData("sid")
    return table_get_depth(res["daobiao"], {"partner", "protect_skill", iSid, iSchool})
end

function CPartner:GetPropData()
    local sid = self:GetData("sid")
    local mData = res["daobiao"]["partner"]["prop"][sid]

    local mResult = {}
    local mEnv = {
        level = self:GetGrade(),
        quality = self:GetQuality(),
    }
    for sKey, rVal in pairs(mData) do
        if type(rVal) == "string" then
            mResult[sKey] = math.floor(formula_string(rVal, mEnv))
        else
            mResult[sKey] = rVal
        end
    end
    return mResult
end

function CPartner:GetPropDataByAttr(sAttr)
    local iSid = self:GetData("sid")
    local mData = res["daobiao"]["partner"]["prop"][iSid]
    if not mData[sAttr] then return end

    local mEnv = {
        level = self:GetGrade(),
        quality = self:GetQuality(),
    }
    if type(mData[sAttr]) == "string" then
        return math.floor(formula_string(mData[sAttr], mEnv))
    else
        return mData[sAttr]
    end
end

function CPartner:GetUpperLimitData(iUpper)
    local sid = self:GetData("sid")
    local mData = res["daobiao"]["partner"]["upperlimit"]
    local id = mData.index[sid][iUpper]
    assert(id, string.format("CPartner:GetUpperLimitData, partner upperlimit config not exist ! id:", id))
    return mData[id]
end

function CPartner:GetExpPropCost(iSid)
    local mData = res["daobiao"]["partner"]["exp"]
    assert(mData[iSid], string.format("CPartner:GetExpPropCost, %d exp add config data not exist!\n", iSid))
    return mData[iSid]
end

function CPartner:GetPointData()
    local sid = self:GetData("sid")
    local iQualiy = self:GetData("quality")
    local mData = res["daobiao"]["partner"]["point"]
    local id = mData.index[sid][iQualiy]
    assert(id, string.format("partner err: %d %d", sid, iQualiy))
    return mData[id]
end

function CPartner:GetUpperData()
    local iUpper = self:GetData("upper")
    local mUpper = res["daobiao"]["partner"]["upper"][iUpper]
    assert(mUpper, string.format("partner err, %d %d %d", self:GetOwnerID(), self:GetSID(), iUpper))
    return mUpper
end

function CPartner:GetUnlockSkillInfo(iGrade)
    local sid = self:GetData("sid")
    local mUnlockSkill = res["daobiao"]["partner"]["skillunlock"]
    local id = mUnlockSkill.index[sid][iGrade]
    if not id then return {} end
    return mUnlockSkill[id] or {}
end

function CPartner:GetMaxGrade()
    local iPlayerId = self:GetOwnerID()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPlayerId)
    if not oPlayer then
        return 0
    end

    local iMaxGrade = oPlayer:GetGrade()
    if 0 >= iMaxGrade then
        iMaxGrade = 2
    end

    local mUpperData = self:GetUpperData()
    if mUpperData then
        iMaxGrade = math.min(iMaxGrade, mUpperData.level)
    end
    return iMaxGrade
end

function CPartner:GetMaxExp()
    local iMaxGrade = self:GetMaxGrade()
    if iMaxGrade <= 0 then
        return 0
    end

    local mUpGrade = res["daobiao"]["upgrade"]
    local iMaxGrade = iMaxGrade + 1
    return mUpGrade[iMaxGrade].partner_exp
end

function CPartner:GetQuality()
    return self:GetData("quality", 0)
end

function CPartner:GetMaxQuality()
    local iQualiy = self:GetData("quality")
    local mQuality = res["daobiao"]["partner"]["quality"]
    return #mQuality
end

function CPartner:GetUpper()
    return self:GetData("upper", 0)
end

function CPartner:GetMaxUpper()
    local mUpperData = res["daobiao"]["partner"]["upper"]
    return #mUpperData
end

function CPartner:GetType()
    return self:GetInfoData()["type"]
end

function CPartner:GetRace()
    return self:GetInfoData()["race"]
end

function CPartner:GetGrade()
    return self:GetData("grade")
end

function CPartner:GetExp()
    return self:GetData("exp")
end

function CPartner:GetName()
    return self:GetData("name")
end

function CPartner:GetSchool()
    return self:GetInfoData()["school"]
end

function CPartner:GetShape()
    return self:GetInfoData()["shape"]
end

function CPartner:GetAIType(oWar)
    local sType = oWar and oWar.m_sClassType or ""
    if sType and gamedefines.PARTNER_AI_NORMAL[sType] then
        return self:GetInfoData()["aitype"]
    else
        return self:GetRoAIType()
    end
end

function CPartner:GetRoAIType()
    return self:GetInfoData()["ro_aitype"]
end

function CPartner:GetMaxHp()
    return self:GetAttr("max_hp")
end

function CPartner:GetMaxMp()
    return self:GetAttr("max_mp")
end

function CPartner:GetHp()
    return self:GetData("hp")
end

function CPartner:GetMp()
    return self:GetData("mp")
end

function CPartner:GetSpeed()
    return self:GetAttr("speed")
end

function CPartner:GetCurePower()
    return self:GetAttr("cure_power")
end

function CPartner:GetMagDefense()
    return self:GetAttr("mag_defense")
end

function CPartner:GetPhyDefense()
    return self:GetAttr("phy_defense")
end

function CPartner:GetMagAttack()
    return self:GetAttr("mag_attack")
end

function CPartner:GetPhyAttack()
    return self:GetAttr("phy_attack")
end

function CPartner:GetPhyCriticalRatio()
    return self:GetAttr("phy_critical_ratio")
end

function CPartner:GetResPhyCriticalRatio()
    return self:GetAttr("res_phy_critical_ratio")
end

function CPartner:GetMagCriticalRatio()
    return self:GetAttr("mag_critical_ratio")
end

function CPartner:GetResMagCriticalRatio()
    return self:GetAttr("res_mag_critical_ratio")
end

function CPartner:GetSealRatio()
    return self:GetAttr("seal_ratio")
end

function CPartner:GetResSealRatio()
    return self:GetAttr("res_seal_ratio")
end

function CPartner:GetHitRatio()
    return self:GetAttr("hit_ratio")
end

function CPartner:GetHitResRatio()
    return self:GetAttr("hit_res_ratio")
end

function CPartner:GetPhyHitRatio()
    return self:GetAttr("phy_hit_ratio")
end

function CPartner:GetPhyHitResRatio()
    return self:GetAttr("phy_hit_res_ratio")
end

function CPartner:GetMagHitRatio()
    return self:GetAttr("mag_hit_ratio")
end

function CPartner:GetMagHitResRatio()
    return self:GetAttr("mag_hit_res_ratio")
end

function CPartner:GetModelInfo()
    local mInfo = {
        shape = self:GetShape(),
        scale = 0,
        color = {0},
        mutate_texture = 0,
        weapon = 0,
        adorn = 0,
    }
    return self:GetData("model_info", mInfo)
end

function CPartner:GetOwnerID()
    return self:GetInfo("pid")
end

function CPartner:GetAttr(sAttr)
    local iValue = self:GetBaseAttr(sAttr) * (100 + self:GetBaseRatio(sAttr)) / 100 + self:GetAttrAdd(sAttr)
    iValue = math.floor(iValue)
    return iValue
end

function CPartner:GetBaseAttr(sAttr)
    if not self:GetData(sAttr) then
        return self:GetPropDataByAttr(sAttr)
    else
        return self:GetData(sAttr)
    end
end

function CPartner:GetBaseRatio(sAttr)
    local iRatio = self.m_oSkillCtrl:GetRatioApply(sAttr) + self.m_oEquipCtrl:GetRatioApply(sAttr)
    -- iRatio = math.floor(iRatio)
    return iRatio
end

function CPartner:GetAttrAdd(sAttr)
    local iValue = self.m_oSkillCtrl:GetApply(sAttr) + self.m_oEquipCtrl:GetApply(sAttr)
    -- iValue = math.floor(iValue)
    return iValue
end

function CPartner:GetUpperAddAttr(sAttr)
    local iUpper = self:GetData("upper") - 1
    if iUpper > 0 then
        local mUpperData = self:GetUpperLimitData(iUpper)
        return mUpperData["add_attr"][sAttr] or 0
    end
    return 0
end

function CPartner:GetScore(bForce)
    if not bForce then
        return global.oScoreCache:GetPartnerScore(self)
    else
        return self:CalScore()
    end
end

function CPartner:CalScore()
    local iScore  = 0 
    iScore = iScore + self:GetPropDataByAttr("score")
    iScore = iScore + self.m_oSkillCtrl:GetScore()
    iScore = iScore + self.m_oEquipCtrl:GetScore()
    return iScore
end

function CPartner:GetScoreByHuZu()
    local iScore  = 0 
    iScore = iScore +self.m_oSkillCtrl:GetScoreByHuZu()
    return iScore
end

--一级属性变动，二级属性也变动
function CPartner:FirstPropChange()
    self:PropChange("agility", "strength", "magic", "endurance", "physique",
        "max_hp", "max_mp", "phy_attack","phy_defense", "mag_attack",
        "mag_defense","cure_power", "speed","hp","mp")
end

--二阶属性统一计算(可能受到一阶属性或者其他类似装备/技能等影响)
function CPartner:SecondLevelPropChange()
    self:PropChange("max_hp", "max_mp", "phy_attack",
        "phy_defense", "mag_attack", "mag_defense",
        "cure_power", "speed","hp","mp","score")
end

--三阶属性统一计算(主要受其他类似装备/技能等影响)
function CPartner:ThreeLevelPropChange()
    self:PropChange("seal_ratio", "res_seal_ratio", "phy_critical_ratio",
        "res_phy_critical_ratio", "mag_critical_ratio", "res_mag_critical_ratio")
end

function CPartner:PropChange(...)
    local l = table.pack(...)
    local oWorldMgr = global.oWorldMgr
    local iOwner = self:GetOwnerID()
    if iOwner then
        oWorldMgr:SetPartnerPropChange(iOwner, self:GetID(), l)
    end
end

function CPartner:ClientPropChange(oPlayer, m)
    local mInfo = self:PartnerInfo(m)
    oPlayer:Send("GS2CPartnerPropChange", {
        partnerid = self.m_iID,
        partner = mInfo,
    })
end

function CPartner:PartnerInfo(m)
    local mRet = {}
    if not m then
        m = PropHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(PropHelperFunc[k], string.format("PartnerInfo fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.PartnerInfo", mRet)
end

function CPartner:PreCheckUseUpgradeProp()
    local iMaxExp = self:GetMaxExp()
    if self:GetData("exp") >= iMaxExp then
        return false
    end
    return true
end

function CPartner:RewardExp(iVal, sReason, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    --local iMaxExp = self:GetMaxExp()
    local iExp = self:GetData("exp")
    assert(iVal > 0, string.format("%d exp err %d %d",self:GetOwnerID(),iExp,iVal))
    --local iVal = math.min(iVal, iMaxExp - iExp)
    local pid = self:GetOwnerID()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    if mArgs.bEffect then
        local iRatio = oPlayer.m_oStateCtrl:GetPartnerExpRatio()
        local iAddExp = math.ceil((iVal * iRatio) / 100)
        iVal = iVal + iAddExp
    end

    local mLogData = oPlayer:LogData()
    mLogData["sid"] = self:GetSID()
    mLogData["exp_old"] = self:GetData("exp", 0)
    mLogData["exp_add"] = iVal
    mLogData["grade_old"] = self:GetGrade()

    self:SetData("exp", iExp + iVal)
    self:CheckUpGrade()
    self:PropChange("exp")

    mLogData["exp_now"] = self:GetData("exp", 0)
    mLogData["grade_now"] = self:GetGrade()
    record.log_db("partner", "exp", mLogData)
    return iVal
end

function CPartner:GetNextExp()
    local iNextGrade = self:GetGrade() + 1
    local mUpGrade = res["daobiao"]["upgrade"]
    return mUpGrade[iNextGrade].partner_exp
end

function CPartner:CheckUpGrade()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwnerID())
    if not oPlayer then
        return
    end
    local iGrade = self:GetGrade()
    local iMaxGrade = self:GetMaxGrade()
    local bRet = true
    local i = iGrade + 1

    while true do
        local iNextExp = self:GetNextExp()
        if not iNextExp then break end

        if i > iMaxGrade then
            break
        end
        if self:GetData("exp") < iNextExp then
            break
        end
        if self:GetGrade() >= oPlayer:GetGrade() then
            break
        end

        self:UpGrade()
        i = i + 1
    end
    if iGrade ~= self:GetGrade() then
        self:Setup()
        self:FullStatus(true)
        self:FirstPropChange()
        self:SecondLevelPropChange()
        self:ThreeLevelPropChange()
    end
    return true
end

function CPartner:UpGrade()
    local iNextExp = self:GetNextExp()
    local iExp = self:GetData("exp", 0) - iNextExp
    self:SetData("exp", iExp)

    local iGrade = self:GetGrade() + 1
    self:SetData("grade", iGrade)
    self:PropChange("exp", "grade")
    global.oScoreCache:Dirty(self:GetOwnerID(), "partnerctrl")
    global.oScoreCache:PartnerDirty(self:GetID())

    self:UnlockSkill()
end

function CPartner:UnlockSkill()
    local iGrade = self:GetGrade()
    local mData = self:GetUnlockSkillInfo(iGrade)
    for _, iSk in ipairs(mData.unlock_skill or {}) do
        local oSk = loadskill.NewSkill(iSk)
        assert(oSk, string.format("partner skill err: %d", iSk))
        self.m_oSkillCtrl:AddSkill(oSk)
        oSk:SkillEffect(self)
    end
    self:PropChange("skill")
end

function CPartner:UpGradeByPlayerGrade(iGrade)
    local iOldGrade = self:GetGrade()
    if iOldGrade >= iGrade then
        return
    end
    self:SetData("grade", iGrade)
    self:PropChange("grade")
    self:UnlockSkillByGrade(iOldGrade, iGrade)

    self:Setup()
    self:FullStatus(true)
    self:FirstPropChange()
    self:SecondLevelPropChange()
    self:ThreeLevelPropChange()

    global.oScoreCache:Dirty(self:GetOwnerID(), "partnerctrl")
    global.oScoreCache:PartnerDirty(self:GetID())
end

function CPartner:UnlockSkillByGrade(iFrom, iGrade)
    iFrom = iFrom or 0
    iGrade = iGrade or self:GetGrade()
    local iSid = self:GetSID()
    local mUnlockSkill = res["daobiao"]["partner"]["skillunlock"]
    local lSkill = {}
    for iNeed, iIdx in pairs(mUnlockSkill.index[iSid]) do
        if iGrade >= iNeed and iNeed > iFrom then
            list_combine(lSkill, mUnlockSkill[iIdx].unlock_skill)
        end
    end
    for _, iSkill in ipairs(lSkill) do
        local oSk = loadskill.NewSkill(iSkill)
        self.m_oSkillCtrl:AddSkill(oSk)
        oSk:SkillEffect(self)
        self:PropChange("skill")
    end
end

function CPartner:IncreaseQuality(iVal)
    assert(iVal > 0, "iVal err, must > 0")
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local iMaxQuality = self:GetMaxQuality()
    local iQualiy = self:GetData("quality")
    iVal = math.min(iVal, iMaxQuality - iQualiy)
    if iVal > 0 then
        local iNewQuality = self:GetData("quality") + iVal
        self:SetData("quality", iNewQuality)
        self.m_oSkillCtrl:UpgradeProtectSkill(self)
        global.oScoreCache:Dirty(self:GetOwnerID(), "partnerctrl")
        global.oScoreCache:PartnerDirty(self:GetID())
        self:Setup()
        self:PropChange("quality")
        self:PropChange("skill")
        self:CalBaseAllProp()
        self:FullStatus(true)
        self:FirstPropChange()
        self:SecondLevelPropChange()
        self:ThreeLevelPropChange()
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwnerID())
        if oPlayer then
            oPlayer.m_oPartnerCtrl:FireIncreaseQuality(self, iNewQuality)
        end
    end
end

function CPartner:IncreaseUpper(iVal)
    assert(iVal > 0, "iVal err, must > 0")
    local oNotifyMgr = global.oNotifyMgr
    local iMaxUpper = self:GetMaxUpper()
    local iUpper = self:GetData("upper")
    iVal = math.min(iVal, iMaxUpper - iUpper)
    if iVal > 0 then
        local iNewUpper = self:GetData("upper") + iVal
        self:SetData("upper", iNewUpper)
        self:CheckUpGrade()
        self:SecondLevelPropChange()
        self:PropChange("upper")

        local iOwner = self:GetOwnerID()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
        if oPlayer then
            oPlayer.m_oPartnerCtrl:FireIncreaseUpper(self, iNewUpper)
        end
    end
end

function CPartner:NeedUpper()
    if self:GetData("upper") == self:GetMaxUpper() then
        return false
    end
    local iGrade = self:GetData("grade")
    local mUpperData = self:GetUpperData()
    if mUpperData.level == iGrade then
        return true
    else
        return false
    end
end

function CPartner:PreCheckRecruit(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local mInfoData = self:GetInfoData()
    local sCondition = mInfoData.pre_condition
    local mArgs = split_string(sCondition, ":")
    local sCdn = mArgs[1]
    assert(sCdn, string.format("partner err: %d %d", oPlayer:GetPid(), self:GetSID() ))
    if sCdn == "LV" then
        if tonumber(mArgs[2]) <= oPlayer:GetGrade() then
            return true
        end
    elseif sCdn == "SM" then
        --师门
    elseif sCdn == "SD" then
        --主线
    end
    return false
end

function CPartner:PreCheckQuality()
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local iQualiy = self:GetData("quality")
    if iQualiy == self:GetMaxQuality() then
        return false
    end
    local mQuality = self:GetQualityData()
    local iGrade = self:GetData("grade")
    if iGrade < mQuality.level then
        return false
    end
    return true
end

function CPartner:PreCheckUpper()
    local oNotifyMgr = global.oNotifyMgr
    if self:GetData("upper") == self:GetMaxUpper() then
        oNotifyMgr:Notify(self:GetOwnerID(), "突破已达上限")
        return false
    end
    local mUpper = self:GetUpperData()
    if self:GetData("grade") < mUpper.level then
        oNotifyMgr:Notify(self:GetOwnerID(), "未达到可突破上限")
        return false
    end
    return true
end

function CPartner:GetRecruitCost()
    local mInfoData = self:GetInfoData()
    return mInfoData.cost, mInfoData.silver
end

function CPartner:GetUpgradeQualityCost()
    local sid = self:GetSID()
    local iQualiy = self:GetData("quality")
    local mQualityCost = res["daobiao"]["partner"]["qualitycost"]
    local id= mQualityCost.index[sid][iQualiy]
    assert(id, string.format("partner err: %d %d %d", self:GetOwnerID(), sid, iQualiy))
    return mQualityCost[id].upgrade_cost, mQualityCost[id].silver
end

function CPartner:GetUpperLimitCost()
    local mUpperLimit = self:GetUpperLimitData(self:GetData("upper"))
    return mUpperLimit.cost
end

function CPartner:GetOwnerApply(sAttr)
    return self.m_oSkillCtrl:GetOwnerApply(sAttr)
end

function CPartner:GetAllOwnerApply()
    return self.m_oSkillCtrl:GetAllOwnerApply()
end

function CPartner:SendNotification(iText, mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sTip = oToolMgr:GetTextData(iText, mTips)
    local sMsg = oToolMgr:FormatColorString(sTip, mArgs)
    oNotifyMgr:Notify(self:GetOwnerID(), sMsg)
end

function CPartner:PackWarInfo(oPlayer, oWar)
    local mRet = {}
    mRet.pid = self:GetID()
    mRet.grade = self:GetGrade()
    mRet.name = self:GetName()
    mRet.school = self:GetSchool()
    mRet.hp = self:GetHp()
    mRet.mp = self:GetMp()
    mRet.max_hp = self:GetMaxHp()
    mRet.max_mp = self:GetMaxMp()
    mRet.physique = self:GetAttr("physique")
    mRet.magic = self:GetAttr("magic")
    mRet.strength = self:GetAttr("strength")
    mRet.endurance = self:GetAttr("endurance")
    mRet.agility = self:GetAttr("agility")
    mRet.model_info = self:GetModelInfo()
    mRet.mag_defense = self:GetMagDefense()
    mRet.phy_defense = self:GetPhyDefense()
    mRet.mag_attack = self:GetMagAttack()
    mRet.phy_attack = self:GetPhyAttack()
    mRet.phy_critical_ratio = self:GetPhyCriticalRatio()
    mRet.res_phy_critical_ratio = self:GetResPhyCriticalRatio()
    mRet.mag_critical_ratio = self:GetMagCriticalRatio()
    mRet.res_mag_critical_ratio = self:GetResMagCriticalRatio()
    mRet.seal_ratio = self:GetSealRatio()
    mRet.res_seal_ratio = self:GetResSealRatio()
--    mRet.hit_ratio = self:GetHitRatio()
--    mRet.hit_res_ratio = self:GetHitResRatio()
    mRet.phy_hit_ratio = self:GetPhyHitRatio()
    mRet.phy_hit_res_ratio = self:GetPhyHitResRatio()
    mRet.mag_hit_ratio = self:GetMagHitRatio()
    mRet.mag_hit_res_ratio = self:GetMagHitResRatio()
    mRet.cure_power = self:GetCurePower()
    mRet.speed = self:GetSpeed()
    mRet.perform = self.m_oSkillCtrl:GetPerform()
    if oPlayer then
        mRet.expertskill = oPlayer.m_oSkillCtrl:PackPartnerExpertSkill()
    end
    mRet.type = self:GetSID()
    mRet.aitype = self:GetAIType(oWar)
    return mRet
end

function CPartner:PackRoData(oPlayer)
    local mData = self:PackWarInfo(oPlayer)
    mData.icon = self:GetShape()
    mData.quality = self:GetData("quality")
    mData.owner = oPlayer:GetPid()
    mData.hp = self:GetMaxHp()
    mData.mp = self:GetMaxMp()
    mData.aitype = self:GetRoAIType()
    mData.score = self:GetScore()
    return mData
end

function CPartner:LeaveWar(mData)
    if mData and mData.hp and mData.mp and mData.gameplay ~= "arena" then
        local iHP = mData.hp
        if iHP<=0 then
            iHP = self:GetMaxHp()
        else
            if mData.relife == true then
                iHP = self:GetMaxHp()
            end
        end
        iHP = math.min(iHP, self:GetMaxHp())
        self:SetData("hp", iHP)

        local iMP = mData.mp
        if iMP<=0 then
            iMP = self:GetMaxMp()
        else
            if mData.relife == true then
                iMP = self:GetMaxMp()
            end
        end
        iMP = math.min(iMP, self:GetMaxMp())
        self:SetData("mp", iMP)
        self:PropChange("mp","hp")
    end
end

function CPartner:SwapProtectSkill(oPlayer, iOldSkill, iNewSkill)
    if iOldSkill == iNewSkill then return end

    local oOldSkill = self.m_oSkillCtrl:GetSkill(iOldSkill)
    local oNewSkill = self.m_oSkillCtrl:GetSkill(iNewSkill)
    if not oOldSkill or oNewSkill then return end

    if not loadskill.GetSkill(iNewSkill) then return end

    local iCostGold = self:GetSwapSkillCost()
    if not oPlayer:ValidGold(iCostGold) then return end
    local mArgs = {tips="消耗了"..iCostGold.."金币"}
    oPlayer:ResumeGold(iCostGold, self:GetName() .. "切换护住技能", mArgs)

    oNewSkill = loadskill.NewSkill(iNewSkill)
    oNewSkill:SetLevel(oOldSkill:Level())

    self.m_oSkillCtrl:DelSkill(iOldSkill)
    self.m_oSkillCtrl:AddSkill(oNewSkill)
    oNewSkill:SkillEffect(self)

    self:PropChange("skill")
end

function CPartner:PackBackendInfo()
    local mData = {}
    mData.sid = self:GetData("sid")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.exp = self:GetData("exp")
    return mData
end

function CPartner:GetServerGrade()
    local iOwner = self:GetOwnerID()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if oPlayer then
        return oPlayer:GetServerGrade()
    end
    return global.oWorldMgr:GetServerGrade()
end
