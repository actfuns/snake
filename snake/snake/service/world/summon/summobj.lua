local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local net = require "base.net"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local summondefines = import(service_path("summon.summondefines"))
local loadskill = import(service_path("summon.skill.loadskill"))
local attrmgr = import(service_path("summon.summonattrmgr"))
local waiguan = import(service_path("summon.waiguan"))
local gamedefines = import(lualib_path("public.gamedefines")) 
local analylog = import(lualib_path("public.analylog"))


function NewSummon(sid)
    local o = CSummon:New(sid)
    return o
end

local function DispatchSummonID()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:DispatchSummonID()
end

function GetSummonData(sid)
    local mData = res["daobiao"]["summon"]["info"][sid]
    assert(mData,string.format("summobj GetSummonData err: %d", sid))
    return mData
end

PropHelperFunc = {}

function PropHelperFunc.id(o)
    return o.m_iID
end

function PropHelperFunc.typeid(o)
    return o:TypeID()
end

function PropHelperFunc.type(o)
    return o:Type()
end

function PropHelperFunc.key(o)
    return o:Key()
end

function PropHelperFunc.name(o)
    return o:Name()
end

function PropHelperFunc.carrygrade(o)
    return o:CarryGrade()
end

function PropHelperFunc.grade(o)
    return o:Grade()
end

function PropHelperFunc.exp(o)
    return o:Exp()
end

function PropHelperFunc.attribute(o)
    return o:Attribute()
end

function PropHelperFunc.point(o)
    return o:Point()
end

function PropHelperFunc.maxaptitude(o)
    return o:MaxAptitude()
end

function PropHelperFunc.curaptitude(o)
    return o:CurAptitude()
end

function PropHelperFunc.life(o)
    return o:Life()
end

function PropHelperFunc.race(o)
    return o:Race()
end

function PropHelperFunc.element(o)
    return o:Element()
end

function PropHelperFunc.score(o)
    return o:Score()
end

function PropHelperFunc.rank(o)
    return o:Rank()
end

function PropHelperFunc.talent(o)
    local mNet = {}
    for k, oSkill in pairs(o.m_mTalents) do
        table.insert(mNet, oSkill:PackNetInfo())
    end
    return mNet
end

function PropHelperFunc.skill(o)
    local mNet = {}
    for _, oSkill in pairs(o.m_lSkills) do
        table.insert(mNet, oSkill:PackNetInfo())
    end
    return mNet
end

function PropHelperFunc.max_hp(o)
    return o:GetMaxHP()
end

function PropHelperFunc.max_mp(o)
    return o:GetMaxMP()
end

function PropHelperFunc.hp(o)
    return o:GetHP()
end

function PropHelperFunc.mp(o)
    return o:GetMP()
end

function PropHelperFunc.basename(o)
    return o:GetConfigName()
end

function PropHelperFunc.phy_attack(o)
    return o:GetPhyAttack()
end

function PropHelperFunc.phy_defense(o)
    return o:GetPhyDefense()
end

function PropHelperFunc.mag_attack(o)
    return o:GetMagAttack()
end

function PropHelperFunc.mag_defense(o)
    return o:GetMagDefense()
end

function PropHelperFunc.speed(o)
    return o:GetSpeed()
end

function PropHelperFunc.grow(o)
    return o:GetData("grow")
end

function PropHelperFunc.model_info(o)
    return o:GetModelInfo()
end

function PropHelperFunc.traceno(o)
    local mTrace = o:GetData("traceno")
    if mTrace then
        return mTrace[2]
    end
    return 0
end

function PropHelperFunc.autoswitch(o)
    return o:GetData("autoswitch", 0)
end

function PropHelperFunc.freepoint(o)
    return o:GetData("freepoint", 0)
end

function PropHelperFunc.got_time(o)
    return o:GetData("got_time", 0)
end

function PropHelperFunc.summon_score(o)
    return o:GetScore()
end

function PropHelperFunc.cycreate_time(o)
    return o:GetData("cycreate_time", 0)
end

function PropHelperFunc.equipinfo(o)
    local mNet = {}
    for k, oEquip in pairs(o.m_mEquip) do
        table.insert(mNet, oEquip:PackItemInfo())
    end
    return mNet
end

function PropHelperFunc.zhenpin(o)
    if o:GetIsZhenPinState() then
        return 1
    end
    return 0
end

function PropHelperFunc.max_hp_unit(o)
    return o:PackAttrUnit("max_hp")
end

function PropHelperFunc.max_mp_unit(o)
    return o:PackAttrUnit("max_mp")
end

function PropHelperFunc.speed_unit(o)
    return o:PackAttrUnit("speed")
end

function PropHelperFunc.mag_defense_unit(o)
    return o:PackAttrUnit("mag_defense")
end

function PropHelperFunc.phy_defense_unit(o)
    return o:PackAttrUnit("phy_defense")
end

function PropHelperFunc.mag_attack_unit(o)
    return o:PackAttrUnit("mag_attack")
end

function PropHelperFunc.phy_attack_unit(o)
    return o:PackAttrUnit("phy_attack")
end

function PropHelperFunc.advance_level(o)
    return o:AdvanceLevel()
end

function PropHelperFunc.bind_ride(o)
    return o:GetBindRide()
end

function PropHelperFunc.use_grow_cnt(o)
    return o:GetData("cnt_usegrow", 0)
end


CSummon = {}
CSummon.__index = CSummon
inherit(CSummon,datactrl.CDataCtrl)

function CSummon:New(sid)
    local o = super(CSummon).New(self)
    o.m_iID = DispatchSummonID()
    o.m_lSkills = {}
    o.m_mTalents = {}
    o.m_mEquip = {}
    o.m_oAttrMgr = attrmgr.NewSummonAttrMgr(sid)
    o.m_oWaiGuan = waiguan.NewWaiGuan(o.m_iID)
    o.m_mBaseAttr = {}
    o.m_mSkillEffect = {}
    o.m_mControlSkill = {}
    o.m_bRecord = false
    o:SetData("sid", sid)
    local mData = res["daobiao"]["summon"]["info"][sid]
    assert(mData,string.format("summobj GetSummonData err: %d", sid))
    -- o:SetInfo("config", GetSummonData(sid))
    return o
end

function CSummon:ConfigData()
    return GetSummonData(self:TypeID())
end

function CSummon:Create(...)
    local iGrade, iIsWild = ...
    if iIsWild then
        self:SetData("wild", 1)
    end
    self:InitGrade(iGrade)
    self:InitAttribute()
    self:InitAutoPoint()
    self:GenerateAptitude()
    self:GenerateGrow()
    self:GenerateLife()
    self:GenerateSkills()
    self:Setup()
    self:FullState()
end

function CSummon:CreateCombine(oSummon1, oSummon2, iLimitGrade, ...)
    self:InitCombineGrade(oSummon1, oSummon2, iLimitGrade)
    self:InitAttribute()
    self:InitAutoPoint()
    self:GenerateCombineAptitude(oSummon1, oSummon2)
    self:GenerateGrow()
    self:GenerateLife()
    self:GenerateTalent()
    local iSkPoint = self:GenerateCombineSkills(oSummon1, oSummon2)
    local iEqPoint = self:GenerateCombineEquip(oSummon1, oSummon2)
    self:Setup()
    self:FullState()
    local iPoint = iSkPoint + iEqPoint
    return iPoint
end

function CSummon:CreateFixedProp(idx, ...)
    local mFixedData = res["daobiao"]["summon"]["fixedproperty"][idx]
    assert(mFixedData, string.format("create summon fixedproperty err idx %d", idx))
    self:InitGrade(mFixedData["grade"])

    local mMaxAptitude = {}
    local mCurAptitude = {}
    for _, aptitude in ipairs(summondefines.APTITUDES) do
        mMaxAptitude[aptitude] = mFixedData["aptitude"][aptitude]
        mCurAptitude[aptitude] = mFixedData["aptitude"][aptitude]
    end
    self:SetData("maxaptitude", mMaxAptitude)
    self:SetData("curaptitude", mCurAptitude)

    local mAttribute = {}
    for _, attr in ipairs(summondefines.ATTRS) do
        mAttribute[attr] = mFixedData["attribute"][attr]
    end
    self:SetData("attribute", mAttribute)

    self:SetData("grow", mFixedData["grow"])
    self:SetData("life", mFixedData["life"])

    for _,skid in ipairs(mFixedData["talent"]) do
        local oSkill = loadskill.NewSkill(skid)
        self.m_mTalents[skid] = oSkill
    end
    for _,skid in ipairs(mFixedData["skill"]) do
        local oSkill = loadskill.NewSkill(skid)
        table.insert(self.m_lSkills, oSkill)
    end
    self:SetData("needbind", mFixedData["bind"])
    self:InitAutoPoint()

    self:Setup()
    self:FullState()
end

function CSummon:CreateSepWashSummon(...)
    self:InitGrade(0)
    self:InitAttribute()
    self:InitAutoPoint()
    self:GenerateSepWashAptitude()
    self:GenerateSepWashGrow()
    self:GenerateLife()
    self:GenerateSepWashSkills()
    self:Setup()
    self:FullState()
end

function CSummon:ID()
    return self.m_iID
end

function CSummon:InitGrade(iGrade)
    iGrade = iGrade or 0
    self:SetData("grade", iGrade)
end

function CSummon:InitCombineGrade(oSummon1, oSummon2, iLimitGrade)
    local iExp = global.oSummonMgr:CalRestoreExp(oSummon1, oSummon2)
    
    local iGrade = 0
    local mUpGrade = res["daobiao"]["upgrade"]
    for i=0, 200 do
        local m = mUpGrade[iGrade + 1]
        if not m then break end

        if iExp < m.summon_exp then 
            break
        end

        if iLimitGrade < iGrade then
            iExp = 0    
            break            
        end

        iGrade = iGrade + 1
        iExp = iExp - m.summon_exp
    end
    self:SetData("exp", iExp)
    self:InitGrade(iGrade)
end

function CSummon:InitAutoPoint()
    local iAutoPoint = self:ConfigData()["autopoint"] or 1
    local mAutoPoint = res["daobiao"]["summon"]["autopoint"][iAutoPoint]
    self:SetAutoPointSheme(mAutoPoint)
    self:SetData("autoswitch", 1)
    if self:GetData("point", 0) > 0 then
        self:AutoAssignPoint()
    end
end

function CSummon:InitAttribute()
    local mAttribute = {}
    for _, attr in ipairs(summondefines.ATTRS) do
        mAttribute[attr] = 10 + self:Grade()
    end

    -- 只分配50点，其他的自动用自动分配方案
    local mAddAttr = {}
    local iPoint = 50
    if summondefines.IsImmortalBB(self:Type()) then
        local iTruePoint = math.floor(iPoint / 5)
        local lAttrs = {"physique", "magic", "strength", "endurance", "agility"}
        for _,sAtrr in pairs(lAttrs) do
            mAttribute[sAtrr] = mAttribute[sAtrr] + iTruePoint
            mAddAttr[sAtrr] = iTruePoint
        end
    else
        local lRatio = {2/5, 2/4, 2/3, 2/2}
        local lAttrs = {"physique", "magic", "strength", "endurance"}
        for idx, iRatio in pairs(lRatio) do
            local iResult = math.random(0, math.floor(iPoint * iRatio))
            mAttribute[lAttrs[idx]] = mAttribute[lAttrs[idx]] + iResult
            mAddAttr[lAttrs[idx]] = iResult
            iPoint = iPoint - iResult
        end
        mAttribute["agility"] = mAttribute["agility"] + iPoint
        mAddAttr["agility"] = iPoint
    end
    self:SetData("attribute", mAttribute)
    self:SetData("initaddattr", mAddAttr)

    self:SetData("point", self:GetData("point", 0) + 5 * self:GetGrade())
end

function CSummon:GenerateAptitude()
    local mMaxAptitude = {}
    local mCurAptitude = {}
    if self:Type() == summondefines.TYPE_WILD or self:Type() == summondefines.TYPE_NORMALBB then
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            mMaxAptitude[aptitude] = math.floor(self:BaseAptitude(aptitude) * (103 + math.random(0, 22)) / 100)
            local iCurAptitude = math.floor(self:BaseAptitude(aptitude) * (102 + math.random(0, 20)) / 100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        end
    elseif summondefines.NotNormalBB(self:Type()) then
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            mMaxAptitude[aptitude] = math.floor(self:BaseAptitude(aptitude) * (103 + math.random(0, 27)) / 100)
            local iCurAptitude = math.floor(self:BaseAptitude(aptitude) * (102 + math.random(0, 23)) / 100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        end
    else
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            mMaxAptitude[aptitude] = self:BaseAptitude(aptitude)
            mCurAptitude[aptitude] = self:BaseAptitude(aptitude)
        end
    end
    self:SetData("maxaptitude", mMaxAptitude)
    self:SetData("curaptitude", mCurAptitude)
end

function CSummon:GenerateCombineAptitude(oSummon1, oSummon2)
    local info = res["daobiao"]["summon"]["aptitcombine"]
    local mRatio = {}
    for k,v in pairs(info) do
        mRatio[k] = v["ratio"]
    end

    local mMaxAptitude = {}
    local mCurAptitude = {}
    local oSummonMgr = global.oSummonMgr
    local mMainApt = self:ConfigData()["main_aptitude"] or {}
    local iMinPercent = oSummonMgr:GetSummonConfig()["combine_min_aptitude"] 
    local iMaxPercent = oSummonMgr:GetSummonConfig()["combine_max_aptitude"]
    for _, aptitude in ipairs(summondefines.APTITUDES) do
        local iAptitude1 = oSummon1:MaxAptitude(aptitude)
        local iAptitude2 = oSummon2:MaxAptitude(aptitude)
        if mMainApt["attr"] == aptitude then
            local iNewRatio = math.random(mMainApt["min"], mMainApt["max"])
            local iMaxAptitude = math.floor((iAptitude1 + iAptitude2) / 2 * iNewRatio / 100)
            mMaxAptitude[aptitude] = math.min(iMaxAptitude, math.floor(self:BaseAptitude(aptitude) * 1.35))
            local iCurAptitude = math.floor(iMaxAptitude * math.random(iMinPercent, iMaxPercent) / 100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        else
            local idx = table_choose_key(mRatio)
            local iRatio = math.random(info[idx]["min"], info[idx]["max"])
            local iMaxAptitude = math.floor((iAptitude1 + iAptitude2) / 2 * iRatio / 100)
            mMaxAptitude[aptitude] = math.min(iMaxAptitude, math.floor(self:BaseAptitude(aptitude) * 1.35))
            local iCurAptitude = math.floor(iMaxAptitude * math.random(iMinPercent, iMaxPercent) / 100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        end
    end
    self:SetData("maxaptitude", mMaxAptitude)
    self:SetData("curaptitude", mCurAptitude)
end

function CSummon:GenerateSepWashAptitude()
    local mMaxAptitude = {}
    local mCurAptitude = {}
    local iZpRate = 90
    local mConfig = global.oSummonMgr:GetSummonConfig()
    for _,m in pairs(mConfig["zp_aptitude_rate"] or {}) do
        if m.grade > self:CarryGrade() then break end
       
        iZpRate = m.ratio
    end

    local iCurRate = mConfig["wash_sep_cur_rate"]
    local iMaxRate = 0
    for _,m in pairs(mConfig["wash_sep_max_rate"] or {}) do
        if m.grade > self:CarryGrade() then break end
       
        iMaxRate = m.ratio
    end
    if self:Type() == summondefines.TYPE_WILD or self:Type() == summondefines.TYPE_NORMALBB then
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            local iMaxAptitude = self:BaseAptitude(aptitude) * 125 / 100
            mMaxAptitude[aptitude] = math.floor(iMaxAptitude * (iZpRate + math.random(iCurRate, iCurRate+iMaxRate))/100)
            local iCurAptitude = math.floor(iMaxAptitude * (iZpRate + math.random(0, iCurRate))/100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        end
    elseif summondefines.NotNormalBB(self:Type()) then
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            local iMaxAptitude = self:BaseAptitude(aptitude) * 130 / 100
            mMaxAptitude[aptitude] = math.floor(iMaxAptitude * (iZpRate + math.random(iCurRate, iCurRate+iMaxRate))/100)
            local iCurAptitude = math.floor(iMaxAptitude * (iZpRate + math.random(0, iCurRate))/100)
            mCurAptitude[aptitude] = math.min(mMaxAptitude[aptitude], iCurAptitude)
        end
    else
        for _, aptitude in ipairs(summondefines.APTITUDES) do
            mMaxAptitude[aptitude] = self:BaseAptitude(aptitude)
            mCurAptitude[aptitude] = self:BaseAptitude(aptitude)
        end
    end
    self:SetData("maxaptitude", mMaxAptitude)
    self:SetData("curaptitude", mCurAptitude)
end

function CSummon:GenerateGrow()
    local mData = res["daobiao"]["summon"]["grow"]
    if self:Type() == summondefines.TYPE_WILD then
        self:SetData("grow", math.floor(self:BaseGrow() * math.random(95, 100) /100 ))
    elseif summondefines.IsBB(self:Type()) then
        local mRatio = {}
        for k, v in pairs(mData) do
            mRatio[k] = v["ratio"]
        end
        local key = extend.Random.choosekey(mRatio)
        local min = mData[key]["min"]
        local max = mData[key]["max"]
        local iGrow = math.floor(math.random(min, max) * self:BaseGrow() / 100)
        self:SetData("grow", iGrow)
    else
        self:SetData("grow", self:BaseGrow() )
    end
end

function CSummon:GenerateSepWashGrow()
    local mConfig = global.oSummonMgr:GetSummonConfig()
    self:SetData("grow", math.ceil(self:BaseGrow()*mConfig["zp_grow"]/100))
end

function CSummon:GenerateLife()
    self:SetData("life", math.floor(self:BaseLife() * math.random(90, 110) / 100 - 50 * self:Grade()) )
end

function CSummon:GenerateTalent()
    for _,skid in ipairs(self:ConfigData()["talent"]) do
        local oSkill = loadskill.NewSkill(skid)
        self.m_mTalents[skid] = oSkill
    end
end

function CSummon:GenerateSkills()
    self:Dirty()
    self:GenerateTalent()

    local mSkill = {}
    for _,skid in ipairs(self:ConfigData()["skill1"]) do
        if not self:GetSKill(skid) then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
        end
    end

    if iType == summondefines.TYPE_WILD then    
        self:GenerateWildSkills()
    else
        self:GenerateNomalSkills()
    end
end

function CSummon:GenerateWildSkills()
    local sFormula = res["daobiao"]["summon"]["calformula"]["skill_rate1"]["formula"]
    local iRatio = tonumber(sFormula) or 0
    for _,skid in ipairs(self:ConfigData()["skill2"]) do
        if not self:GetSKill(skid) and math.random(1, 100) <= iRatio then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
        end
    end
end

function CSummon:GenerateNomalSkills()
    local sFormula = res["daobiao"]["summon"]["calformula"]["skill_rate2"]["formula"]
    local mRatio = formula_string(sFormula, {})

    local iCnt = 1
    for _,skid in ipairs(self:ConfigData()["skill2"]) do
        local iRatio = mRatio[iCnt] or 0
        if not self:GetSKill(skid) and math.random(1, 100) <= iRatio then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
        end
        iCnt = iCnt + 1
    end
end

function CSummon:GenerateSepWashSkills()
    self:Dirty()
    self:GenerateTalent()

    for _,skid in ipairs(self:ConfigData()["skill1"]) do
        if not self:GetSKill(skid) then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
        end
    end
    for _,skid in ipairs(self:ConfigData()["skill2"]) do
        if not self:GetSKill(skid) then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
        end
    end    
end

function CSummon:GenerateCombineEquip(oSummon1, oSummon2)
    local iPoint = 0
    for _, oEquip in pairs(oSummon1:GetEquips()) do
        iPoint = iPoint + oEquip:GetPoint()
    end
    for _, oEquip in pairs(oSummon2:GetEquips()) do
        iPoint = iPoint + oEquip:GetPoint()
    end
    return iPoint
end

function CSummon:GenerateCombineSkills(oSummon1, oSummon2)
    self:Dirty()
    local mHasSkill, iPoint = {}, 0
    -- for _,skid in ipairs(self:ConfigData()["skill1"]) do
    --     local oSkill = loadskill.NewSkill(skid)
    --     oSkill:SetInnate()
    --     table.insert(self.m_lSkills, oSkill)
    --     mHasSkill[skid] = true
    -- end
    local mCombineSkill, lSortSkill = {}, {}
    for _,oSkill in ipairs(oSummon1:GetSkillObjList()) do
        mCombineSkill[oSkill:SkID()] = {oSkill:GetPoint(), oSkill:IsInnate()}
        table.insert(lSortSkill, {oSkill:SkID(), math.random(20)})
    end
    for _,oSkill in ipairs(oSummon2:GetSkillObjList()) do
        if not mCombineSkill[oSkill:SkID()] then
            mCombineSkill[oSkill:SkID()] = {oSkill:GetPoint(), oSkill:IsInnate()}
            table.insert(lSortSkill, {oSkill:SkID(), math.random(20)})    
        else
            if math.random(100) <= 50 then
                mCombineSkill[oSkill:SkID()] = {oSkill:GetPoint(), oSkill:IsInnate()}
            end
        end
    end
    table.sort(lSortSkill, function (a, b)
        return a[2] > b[2]
    end)

    local iTalentCnt = table_count(self.m_mTalents)
    local iSkCnt = self:GetSKillCnt() + 1
    local mSkRatio = res["daobiao"]["summon"]["skcntcombine"]
    for _,m in pairs(lSortSkill) do
        local iSk = m[1]
        local mTmpSkill = mCombineSkill[iSk] or {}
        local iPt, bInnate = 0, false
        if #mTmpSkill >= 2 then
            iPt, bInnate = mTmpSkill[1], mTmpSkill[2]
        end

        if self:GetSKillCnt() >= 10 then
            iPoint = iPoint + iPt
            goto continue
        end     
        if mHasSkill[iSk] or not mSkRatio[iSkCnt] then
            iPoint = iPoint + iPt
            goto continue
        end
        if math.random(100) <= mSkRatio[iSkCnt]["ratio"] then
            local oSkill = loadskill.NewSkill(iSk)
            if bInnate then
                oSkill:SetInnate()
            end
            table.insert(self.m_lSkills, oSkill)
            mHasSkill[iSk] = true  
        else
            iPoint = iPoint + iPt
        end
        iSkCnt = iSkCnt + 1
        ::continue::
    end
    for _,skid in ipairs(self:ConfigData()["skill1"]) do
        if self:GetSKillCnt() >= 10 then break end
        if not mSkRatio[iSkCnt] then break end

        if not mHasSkill[skid] and math.random(100) <= mSkRatio[iSkCnt]["ratio"] then
            local oSkill = loadskill.NewSkill(skid)
            oSkill:SetInnate()
            table.insert(self.m_lSkills, oSkill)
            mHasSkill[skid] = true
        end
        iSkCnt = iSkCnt + 1
    end
    return iPoint
end

function CSummon:Release()
    for sk, oSkill in pairs(self.m_lSkills) do
        baseobj_safe_release(oSkill)
    end
    self.m_lSkills = {}
    for sk, oSkill in pairs(self.m_mTalents) do
        baseobj_safe_release(oSkill)
    end
    self.m_mTalents = {}
    for _, oSkill in pairs(self.m_mControlSkill) do
        baseobj_safe_release(oSkill)
    end

    baseobj_safe_release(self.m_oAttrMgr)
    self.m_oAttrMgr = nil
    baseobj_safe_release(self.m_oWaiGuan)
    self.m_oWaiGuan = nil
    for _, oEquip in pairs(self.m_mEquip) do
        baseobj_safe_release(oEquip)
    end
    super(CSummon).Release(self)
end

function CSummon:Load(mData)
    mData = mData or {}
    self:SetData("traceno", mData.traceno)
    self:SetData("sid", mData.sid)
    self:SetData("wild", mData.wild)
    self:SetData("name", mData.name)
    self:SetData("grade", mData.grade)
    self:SetData("exp", mData.exp)
    self:SetData("attribute", mData.attribute)
    self:SetData("point", mData.point)
    self:SetData("maxaptitude", mData.maxaptitude)
    self:SetData("curaptitude", mData.curaptitude)
    self:SetData("grow", mData.grow)
    self:SetData("life", mData.life)
    self:SetData("hp", mData.hp)
    self:SetData("mp", mData.mp)
    self:SetData("autopoint", mData.autopoint)
    self:SetData("autoswitch", mData.autoswitch)
    self:SetData("cnt_usegrow", mData.usegrow)
    self:SetData("freepoint", mData.freepoint)
    self:SetData("initaddattr", mData.initaddattr)
    self:SetData("autopf", mData.autopf)
    self:SetData("cycreate_time", mData.cycreate_time)
    self:SetData("needbind", mData.needbind)
    self:SetData("zhenpin", mData.zhenpin)
    self:SetData("wash_cnt", mData.wash_cnt)
    self:SetData("Bind", mData.bind)
    self:SetData("bind_ride", mData.bind_ride)
    self:SetData("advance_level", mData.advance_level)

    for _, info in pairs(mData.skills or {}) do
        local skid = info["skid"]
        local oSkill = loadskill.LoadSkill(skid, info)
        table.insert(self.m_lSkills, oSkill)
    end
    for sk, info in pairs(mData.talent or {}) do
        local skid = tonumber(sk)
        local oSkill = loadskill.LoadSkill(skid, info)
        self.m_mTalents[skid] = oSkill
    end
    self.m_oWaiGuan:Load(mData.waiguan)

    for _,m in pairs(mData.equip or {}) do
        local oEquip = global.oItemLoader:LoadItem(m["sid"], m)
        self.m_mEquip[oEquip:SID()] = oEquip
    end
end

function CSummon:Save()
    local mData = {}
    mData.traceno = self:GetData("traceno")
    mData.sid = self:GetData("sid")
    mData.wild = self:GetData("wild")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.exp = self:GetData("exp")
    mData.attribute = self:GetData("attribute")
    mData.point = self:GetData("point")
    mData.maxaptitude = self:GetData("maxaptitude")
    mData.curaptitude = self:GetData("curaptitude")
    mData.grow = self:GetData("grow")
    mData.life = self:GetData("life")
    mData.mp = self:GetData("mp")
    mData.hp = self:GetData("hp")
    mData.autopoint = self:GetData("autopoint")
    mData.autoswitch = self:GetData("autoswitch")
    mData.usegrow = self:GetData("cnt_usegrow")
    mData.freepoint = self:GetData("freepoint")
    mData.initaddattr = self:GetData("initaddattr")
    mData.autopf = self:GetData("autopf")
    mData.cycreate_time = self:GetData("cycreate_time")
    mData.needbind = self:GetData("needbind")
    mData.zhenpin = self:GetData("zhenpin")
    mData.wash_cnt = self:GetData("wash_cnt")
    mData.bind = self:GetData("Bind")
    mData.bind_ride = self:GetData("bind_ride")
    mData.advance_level = self:GetData("advance_level")

    local mSkill = {}
    for _, oSkill in pairs(self.m_lSkills) do
        table.insert(mSkill, oSkill:Save())
    end
    mData.skills = mSkill

    local mSkill = {}
    for sk, oSkill in pairs(self.m_mTalents) do
        sk = db_key(sk)
        mSkill[sk] = oSkill:Save()
    end
    mData.talent = mSkill
    mData.waiguan = self.m_oWaiGuan:Save()

    mData.equip = {}
    for _,oEquip in pairs(self.m_mEquip) do
        table.insert(mData.equip, oEquip:Save())
    end
    return mData
end

function CSummon:UnDirty()
    super(CSummon).UnDirty(self)
    for _, oSkill in pairs(self.m_lSkills) do
        if oSkill:IsDirty() then
            oSkill:UnDirty()
        end
    end
    for _, oSkill in pairs(self.m_mTalents) do
        if oSkill:IsDirty() then
            oSkill:UnDirty()
        end
    end
    self.m_oWaiGuan:UnDirty()
end

function CSummon:IsDirty()
    local bDirty = super(CSummon).IsDirty(self)
    if bDirty then
        return true
    end
    for _, oSkill in pairs(self.m_lSkills) do
        if oSkill:IsDirty() then
            return true
        end
    end
    for _, oSkill in pairs(self.m_mTalents) do
        if oSkill:IsDirty() then
            return true
        end
    end
    if self.m_oWaiGuan:IsDirty() then
        return true
    end
    return false
end

function CSummon:CalBaseAttr(sAttr, mEnv)
    local mData = res["daobiao"]["summon"]["calformula"][sAttr]
    if not mData then return 0 end

    local sFormula = mData["formula"]
    if not mEnv then
        mEnv = self:AttrFormulaEnv()
    end 

    local iValue = formula_string(sFormula, mEnv)
    return iValue
end

function CSummon:AttrFormulaEnv()
    local mEnv = {grade=self:Grade(), grow=self:Grow()}   
    for _, attr in pairs(summondefines.ATTRS) do
        mEnv[attr] = self:Attribute(attr)
    end    
    for _, attr in pairs(summondefines.APTITUDES) do
        mEnv[attr] = self:CurAptitude(attr)
    end
    return mEnv    
end

function CSummon:Setup()
    local mEnv = self:AttrFormulaEnv()
    local iMaxHp = self:CalBaseAttr("max_hp", mEnv)
    local iMaxMp = self:CalBaseAttr("max_mp", mEnv)
    local iAttack = self:CalBaseAttr("phy_attack", mEnv)
    local iDefense = self:CalBaseAttr("phy_defense", mEnv)
    local iMagAttack = self:CalBaseAttr("mag_attack", mEnv)
    local iMagDefense = self:CalBaseAttr("mag_defense", mEnv)
    local iSpeed = self:CalBaseAttr("speed", mEnv)
    self:SetBaseAttr("max_hp", iMaxHp)
    self:SetBaseAttr("max_mp", iMaxMp)
    self:SetBaseAttr("phy_attack", iAttack)
    self:SetBaseAttr("phy_defense", iDefense)
    self:SetBaseAttr("mag_attack", iMagAttack)
    self:SetBaseAttr("mag_defense", iMagDefense)
    self:SetBaseAttr("speed", iSpeed)

    local iPhyCriRatio = self:CalBaseAttr("phy_critical_ratio", mEnv)
    local iPhyResCriRatio = self:CalBaseAttr("res_phy_critical_ratio", mEnv)
    local iMagCriRatio = self:CalBaseAttr("mag_critical_ratio", mEnv)
    local iMagResCriRatio = self:CalBaseAttr("res_mag_critical_ratio", mEnv)
    local iSealRatio = self:CalBaseAttr("seal_ratio", mEnv)
    local iResSealRatio = self:CalBaseAttr("res_seal_ratio", mEnv)
    local iCurePower = self:CalBaseAttr("cure_power", mEnv)
    self:SetBaseAttr("phy_critical_ratio", iPhyCriRatio)
    self:SetBaseAttr("res_phy_critical_ratio", iPhyResCriRatio)
    self:SetBaseAttr("mag_critical_ratio", iMagCriRatio)
    self:SetBaseAttr("res_mag_critical_ratio", iMagResCriRatio)
    self:SetBaseAttr("seal_ratio", iSealRatio)
    self:SetBaseAttr("res_seal_ratio", iResSealRatio)
    self:SetBaseAttr("cure_power", iCurePower)

    local iPhyHitRatio = self:CalBaseAttr("phy_hit_ratio", mEnv)
    self:SetBaseAttr("phy_hit_ratio", iPhyHitRatio)
    local iPhyHitResRatio = self:CalBaseAttr("phy_hit_res_ratio", mEnv)
    self:SetBaseAttr("phy_hit_res_ratio", iPhyHitResRatio)
    local iMagHitRatio = self:CalBaseAttr("mag_hit_ratio", mEnv)
    self:SetBaseAttr("mag_hit_ratio", iMagHitRatio)
    local iMagHitResRatio = self:CalBaseAttr("mag_hit_res_ratio", mEnv)
    self:SetBaseAttr("mag_hit_res_ratio", iMagHitResRatio)
    
    self.m_oAttrMgr:ClearApply()
    self.m_oAttrMgr:ClearRatioApply()
    self.m_mSkillEffect = {}
    self:SetupSkill()
    self:SetupEquip()
    self:CheckZhenPin()
    self:SetupControl()
    self:SetData("hp", math.min(self:GetData("hp", 1), self:GetMaxHP()))
    self:SetData("mp", math.min(self:GetData("mp", 1), self:GetMaxMP()))
end

function CSummon:GetMaxHP()
    return self:GetAttr("max_hp")
end

function CSummon:GetMaxMP()
    return self:GetAttr("max_mp")
end

function CSummon:GetPhyAttack()
    return self:GetAttr("phy_attack")
end

function CSummon:GetPhyDefense()
    return self:GetAttr("phy_defense")
end

function CSummon:GetMagAttack()
    return self:GetAttr("mag_attack")
end

function CSummon:GetMagDefense()
    return self:GetAttr("mag_defense")
end

function CSummon:GetSpeed()
    return self:GetAttr("speed")
end

function CSummon:SetBaseAttr(attr, val)
    self.m_mBaseAttr[attr] = val
end

function CSummon:GetBaseAttr(attr)
    return self.m_mBaseAttr[attr] or 0
end

function CSummon:GetAttr(sAttr)
    return math.floor(self:GetBaseAttr(sAttr)  * (100 + self:QueryRatioApply(sAttr)) / 100 + self:QueryApply(sAttr)) 
end

function CSummon:SetSkillEffect(iSource, bFlag)
    self.m_mSkillEffect[iSource] = bFlag 
end

function CSummon:GetSkillEffect()
    return self.m_mSkillEffect
end

function CSummon:AddApply(sAttr, iVal, iSource)
    self.m_oAttrMgr:AddApply(sAttr, iSource, iVal)
    self:PropChange(sAttr)
    self:PropSecondChange(sAttr)
end

function CSummon:QueryApply(sAttr)
    return self.m_oAttrMgr:GetApply(sAttr)
end

function CSummon:AddRatioApply(sAttr, iVal, iSource)
    self.m_oAttrMgr:AddRatioApply(sAttr, iSource, iVal)
    self:PropChange(sAttr)
    self:PropSecondChange(sAttr)
end

function CSummon:QueryRatioApply(sAttr)
    return self.m_oAttrMgr:GetRatioApply(sAttr)
end

function CSummon:RemoveApply(iSource)
    local mPropChange = self.m_oAttrMgr:RemoveSource(iSource)
    for sAttr,_ in pairs(mPropChange) do
        self:PropChange(sAttr)    
    end
end

function CSummon:GetScore(bForce)
    if not bForce then
        return global.oScoreCache:GetSummonScore(self)
    else
        return self:CalScore()
    end
end

function CSummon:CalScore()
    local iScore = 0
    if self:Type() == summondefines.TYPE_WILD then
        return iScore
    end
    
    for _,oSkill in pairs(self.m_lSkills) do
        iScore = iScore + oSkill:GetScore()
    end
    for _,oSkill in pairs(self.m_mTalents) do
        iScore = iScore + oSkill:GetScore()
    end
    for _,oEquip in pairs(self.m_mEquip) do
        iScore = iScore + oEquip:GetScore()
    end
    -- for _,oSkill in pairs(self.m_mControlSkill) do
    --     iScore = iScore + oSkill:GetScore()
    -- end
    local iSumAptitudes = 0
    for _, aptitude in ipairs(summondefines.APTITUDES) do
        iSumAptitudes = iSumAptitudes + self:CurAptitude(aptitude)
    end
    local iGrow = self:GetData("grow",0)
    local sScore = self:ConfigData()["score"]
    local iScore = iScore + formula_string(sScore,{grow = iGrow,aptitude = iSumAptitudes})
    iScore = math.floor(iScore)
    return iScore
end

function CSummon:RefreshOwnerScore()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        oPlayer:PropChange("score")
    end
end

function CSummon:GetAutoPerform()
    return self:GetData("autopf")
end

function CSummon:SetAutoPerform(iAutoPf)
    self:SetData("autopf", iAutoPf)
end

function CSummon:SetupSkill()
    for _, oSkill in pairs(self:GetAllSkills()) do
        oSkill:SkillUnEffect(self)
        oSkill:SkillEffect(self)
    end
end

function CSummon:SetupEquip()
    for _,oEquip in pairs(self.m_mEquip) do
        oEquip:EquipUnEffect(self)
        oEquip:EquipEffect(self)
    end
end

function CSummon:PackWarInfo(oPlayer)
    local mRet = {}
    mRet.sum_id = self.m_iID
    mRet.grade = self:Grade()
    mRet.name = self:Name()
    mRet.hp = self:GetHP()
    mRet.mp = self:GetMP()
    mRet.max_hp = self:GetMaxHP()
    mRet.max_mp = self:GetMaxMP()
    mRet.physique = self:Attribute("physique")
    mRet.magic = self:Attribute("magic")
    mRet.strength = self:Attribute("strength")
    mRet.endurance = self:Attribute("endurance")
    mRet.agility = self:Attribute("agility")
    mRet.model_info = self:GetModelInfo()
    mRet.mag_defense = self:GetMagDefense()
    mRet.phy_defense = self:GetPhyDefense()
    mRet.mag_attack = self:GetMagAttack()
    mRet.phy_attack = self:GetPhyAttack()
    mRet.phy_critical_ratio = self:GetAttr("phy_critical_ratio")
    mRet.res_phy_critical_ratio = self:GetAttr("res_phy_critical_ratio")
    mRet.mag_critical_ratio = self:GetAttr("mag_critical_ratio")
    mRet.res_mag_critical_ratio = self:GetAttr("res_mag_critical_ratio")
    mRet.seal_ratio = self:GetAttr("seal_ratio")
    mRet.res_seal_ratio = self:GetAttr("res_seal_ratio")
--    mRet.hit_ratio = self.m_iHitRatio
--    mRet.hit_res_ratio = self.m_iHitResRatio
    mRet.phy_hit_ratio = self:GetAttr("phy_hit_ratio")
    mRet.phy_hit_res_ratio = self:GetAttr("phy_hit_res_ratio")
    mRet.mag_hit_ratio = self:GetAttr("mag_hit_ratio")
    mRet.mag_hit_res_ratio = self:GetAttr("mag_hit_res_ratio")
    mRet.cure_power = self:GetAttr("cure_power")
    mRet.speed = self:GetSpeed()
    mRet.perform = self:GetPerform()
    mRet.element  = self:Element()
    mRet.type = self:TypeID()
    mRet.expertskill = oPlayer.m_oSkillCtrl:PackPartnerExpertSkill()
    mRet.auto_perform = self:GetAutoPerform()
    mRet.carrygrade = self:CarryGrade()
    return mRet
end

function CSummon:PackRoData(oPlayer)
    local mData = self:PackWarInfo(oPlayer)
    mData.auto_perform = nil
    mData.icon = self:Shape()
    mData.hp = self:GetMaxHP()
    mData.mp = self:GetMaxMP()
    mData.score = self:GetScore()
    return mData
end

function CSummon:GetPerform()
    local mWarSkill = {}
    for iSk, oSkill in pairs(self:GetAllSkills()) do
        mWarSkill[iSk] = oSkill
    end
    for iSk, oSkill in pairs(self:GetEquipSkills()) do
        mWarSkill[iSk] = oSkill
    end 

    local mPerform = {}
    for iSk, oSkill in pairs(mWarSkill) do
        local iTopSk = oSkill:TopSkill()
        if iTopSk and mWarSkill[iTopSk] then
            goto continue
        end
        for iPerform, lv in pairs(oSkill:GetPerformList()) do
            local iOld = mPerform[iPerform] or 0
            if iOld <= lv then
                mPerform[iPerform] = lv
            end
        end
        ::continue::
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

function CSummon:GetTraceName()
    local iOwner,iTraceNo = table.unpack(self:GetData("traceno",{}))
   return string.format("%s %d:<%d,%d>",self:Name(),self:TypeID(),iOwner,iTraceNo)
end

function CSummon:GetModelInfo()
    local mRet = {}
    mRet.shape = self:Shape()
    mRet.figure = self:Shape()
    mRet.ranse_summon = self.m_oWaiGuan:GetCurColor()
    return mRet
end

function CSummon:TypeID()
    return self:GetData("sid")
end

function CSummon:Shape()
    return self:ConfigData()["shape"]
end

function CSummon:ConfigType()
    return self:ConfigData()["type"]
end

function CSummon:Type()
    if self:GetData("wild") == 1 then
        return summondefines.TYPE_WILD
    end
    return self:ConfigType()
end

function CSummon:IsWild()
    return self:GetData("wild") == 1
end

function CSummon:IsNormalBB()
    return self:Type() == summondefines.TYPE_NORMALBB
end

function CSummon:IsHoly()
    return self:ConfigType() == summondefines.TYPE_HOLYBB
end

function CSummon:Grade()
    return self:GetData("grade", 0)
end

--和人物统一接口
function CSummon:GetGrade()
    return self:GetData("grade",0)
end

function CSummon:Exp()
    return self:GetData("exp", 0)
end

function CSummon:CarryGrade()
    return self:ConfigData()["carry"]
end

function CSummon:GetConfigName()
    return self:ConfigData()["name"]
end

function CSummon:Name()
    if not self:GetData("name") or self:GetData("name") == "" then
        return self:ConfigData()["name"]
    end
    return self:GetData("name")
end

function CSummon:SetName(name)
    self:SetData("name", name)
    self:PropChange("name")
end

function CSummon:GetHP()
    return self:GetData("hp")
end

function CSummon:GetMP()
    return self:GetData("mp")
end

function CSummon:Attribute(attr)
    if not attr then
        return self:GetData("attribute", {})
    end
    return self:GetData("attribute", {})[attr]
end

function CSummon:AddAttribute(attr, point)
    local mAttribute = self:GetData("attribute", {})
    mAttribute[attr] = (mAttribute[attr] or 0) + point
    self:SetData("attribute", mAttribute)
    self:PropChange("attribute","score")
end

function CSummon:Point()
    return self:GetData("point", 0)
end

function CSummon:AddPoint(point)
    self:SetData("point", math.max(0, self:GetData("point", 0) + point))
    self:PropChange("point")
end

function CSummon:BaseAptitude(key)
    return self:ConfigData()["aptitude"][key]
end

function CSummon:MaxAptitude(key)
    if not key then
        return self:GetData("maxaptitude", {})
    end
    return self:GetData("maxaptitude", {})[key]
end

function CSummon:CurAptitude(key)
    if not key then
        return self:GetData("curaptitude", {})
    end
    return self:GetData("curaptitude", {})[key]
end

function CSummon:AddCurAptitude(key, val)
    val = tonumber(val)
    local oNotifyMgr = global.oNotifyMgr 
    local mCurAptitude = self:GetData("curaptitude")
    assert(mCurAptitude[key], string.format("AddCurAptitude fail err key %s", key))
    val = math.min(val, self:MaxAptitude(key) - mCurAptitude[key])
    mCurAptitude[key] = mCurAptitude[key] + val
    self:SetData("curaptitude", mCurAptitude)
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
    end
    global.oScoreCache:SummonDirty(self:ID())
    self:CheckZhenPin()
    self:PropChange("curaptitude", "score", "rank", "summon_score", "zhenpin")
    self:RefreshOwnerScore()
    local sMsg = string.format("培养成功，#G%s#n增加#G%d#n", summondefines.APTITUDE_NAMES[key], val)
    oNotifyMgr:Notify(self:GetOwner(), sMsg)
end

function CSummon:BaseGrow()
    return self:ConfigData()["grow"]
end

function CSummon:Grow()
    return self:GetData("grow", 0)
end

function CSummon:AddGrow(val)
    val = tonumber(val)
    self:SetData("grow", self:GetData("grow") + val)
end

function CSummon:OnAddGrow()
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
    end
    self:CheckZhenPin()
    global.oScoreCache:SummonDirty(self:ID())
    self:PropChange("grow", "score", "rank","summon_score", "zhenpin")
    self:RefreshOwnerScore()
end

function CSummon:BaseLife()
    return self:ConfigData()["life"]
end

function CSummon:Life()
    return self:GetData("life", 0)
end

function CSummon:AddLife(iLife)
    if self:IsForeverLife() then return end

    local life = math.max(0, self:Life() + iLife)
    life = math.min(life, 60000) 
    self:SetData("life", life)
    self:PropChange("life")
end

function CSummon:IsForeverLife()
    return summondefines.IsImmortalBB(self:Type())
end

function CSummon:CanFight(oPlayer)
    local oSummonMgr = global.oSummonMgr
    if self:Grade() > oPlayer:GetGrade() + 10 then
        return false, oSummonMgr:GetText(1054, {summon=self:Name(), level=10})
    end
    if not self:IsForeverLife() and self:Life() < 50 then
        return false, oSummonMgr:GetText(2033, {summon=self:Name(), amount=50})
    end
    return true
end

function CSummon:Race()
    return self:ConfigData()["race"]
end

function CSummon:SkillCntMax()
    return 10
end

function CSummon:GetAllSkills()
    local mAllSkill = {}
    for _, oSkill in pairs(self.m_lSkills) do
        mAllSkill[oSkill:SkID()] = oSkill
    end
    for id, oSkill in pairs(self.m_mTalents) do
        mAllSkill[id] = oSkill
    end
    for id, oSkill in pairs(self.m_mControlSkill) do
        mAllSkill[id] = oSkill
    end
    return mAllSkill
end

function CSummon:GetEquipSkills()
    local mSkill = {}
    for _,oEquip in pairs(self.m_mEquip) do
        for _, oSkill in pairs(oEquip:GetSkills()) do
            mSkill[oSkill:SkID()] = oSkill
        end
    end
    return mSkill
end

function CSummon:GetConfigSkills()
    local lSkill = {}
    extend.Array.append(lSkill, self:ConfigData()["skill1"])
    extend.Array.append(lSkill, self:ConfigData()["skill2"])
    return lSkill
end

function CSummon:GetLackingSkill()
    local lConfig = self:GetConfigSkills()
    local lLack = {}
    for _, v in pairs(lConfig) do
        if not self:GetSKill(v) then
            table.insert(lLack, v)
        end
    end
    return lLack
end

function CSummon:GetSKillList()
    local lSkIds = {}
    for _, oSk in pairs(self.m_lSkills) do
        table.insert(lSkIds, oSk:SkID())
    end
    return lSkIds
end

function CSummon:GetEquips()
    return self.m_mEquip
end

function CSummon:GetSkillObjList()
    return self.m_lSkills
end

function CSummon:GetSKillCnt(bTalent)
    local iCnt = #self.m_lSkills
    if bTalent then
        iCnt = iCnt + table_count(self.m_mTalents)
    end
    return iCnt
end

function CSummon:GetSKill(skid)
    for iIdx,oSkill in pairs(self.m_lSkills) do
        if oSkill:SkID() == skid then
            return oSkill, iIdx
        end
    end
    return nil, nil
end

function CSummon:GetSkillMap()
    local mSkill = {}
    for _,oSKill in pairs(self.m_lSkills) do
        mSkill[oSKill:SkID()] = oSKill
    end
    return mSkill
end

function CSummon:RemoveSkill(skid)
    local oSkill, iIdx = self:GetSKill(skid)
    if oSkill then
        self:Dirty()
        table.remove(self.m_lSkills, iIdx)
        if self:GetOwner() then
            global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
        end
        global.oScoreCache:SummonDirty(self:ID())
        oSkill:SkillUnEffect(self)
        self:PropChange("skill", "score", "rank", "summon_score", "zhenpin")
        self:RefreshOwnerScore()
    end
    return oSkill, iIdx
end

function CSummon:AddSkill(skid, lv, iIdx)
    local oSk = self:GetSKill(skid)
    if oSk then return end

    self:Dirty()
    local oSkill = loadskill.NewSkill(skid, lv)
    table.insert(self.m_lSkills, iIdx or (#self.m_lSkills + 1), oSkill)
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
    end
    self:CheckZhenPin()
    global.oScoreCache:SummonDirty(self:ID())
    oSkill:SkillEffect(self)
    self:PropChange("skill", "score", "rank", "summon_score", "zhenpin")
    self:RefreshOwnerScore()
    self:Record()
    return oSkill
end

function CSummon:LearnSkillCostTot()
    local iCost = 0
    for _, oSkill in pairs(self.m_lSkills) do
        iCost = iCost + oSkill:LearnCostTot()
    end
    return iCost
end

function CSummon:Element()
    return self:ConfigData()["element"]
end

function CSummon:IsShowUI()
    return self:ConfigData()["show_ui"] > 0
end

function CSummon:Score()
    local score = self:ConfigData()["base_score"] or 0
    for _, aptitude in ipairs(summondefines.APTITUDES) do
        score = score + self:CurAptitude(aptitude)
    end
    for _, oSkill in pairs(self.m_lSkills) do
        score = score + (oSkill:Level() * 60 + 300)
    end
    for sk, oSkill in pairs(self.m_mTalents) do
        score = score + oSkill:Score()
    end
    return score + self:Grow() + 3700
end

function CSummon:Rank()
    local iScore = self:GetScore()
    local mData = res["daobiao"]["summon"]["score"]
    for k, info in pairs(mData) do
        local min, max = table.unpack(info["score"])
        local sRank = info["rank"]
        if max then
            if iScore >= min and iScore <= max then
                return sRank
            end
        else
            if iScore > min then
                return sRank
            end
        end
    end
end

function CSummon:NeedBind()
    if self:GetData("needbind", 0) > 0 then 
        return true
    end
    return false
end

function CSummon:Bind(iOwner)
    self:SetData("Bind",iOwner)
    self:SetData("needbind", nil)
    self:PropChange("key")
end

function CSummon:IsBind()
    if self:GetData("Bind",0) ~= 0 then
        return true
    end
    return false
end

function CSummon:Key()
    local key = 0
    if self:IsBind() then
        key = key | summondefines.KEY_BIND
    end
    return key
end

function CSummon:IsOpenAutoPoint()
    return self:GetData("autoswitch") == 1
end

function CSummon:SetAutoSwitch(iFlag)
    if iFlag == 1 then
        self:SetData("autoswitch", 1)
    else
        self:SetData("autoswitch", 0)
    end
    self:PropChange("autoswitch")
end

function CSummon:SetAutoPointSheme(mScheme)
    local mAuto = {}
    for _, attr in ipairs(summondefines.ATTRS) do
        if mScheme[attr] > 0 then
            mAuto[attr] = mScheme[attr]
        end
    end
    self:SetData("autopoint", mAuto)
end

function CSummon:AutoAssignPoint()
    local iTot = 0
    for attr, point in pairs(self:GetData("autopoint")) do
        iTot = iTot + point
    end
    local iPoint = self:GetData("point", 0)
    local iPer = math.floor(iPoint / iTot)
    local iAssign = iPer * iTot
    if iAssign < 0 then
        return
    end
    for attr, point in pairs(self:GetData("autopoint")) do
        self:AddAttribute(attr, point * iPer)
    end
    self:SetData("point", iPoint - iAssign)
end

function CSummon:RewardExp(iRewardExp, sReason, mArgs)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if self:Grade() >= oPlayer:GetGrade() + 5 then
        oChatMgr:HandleMsgChat(oPlayer, string.format("%s的等级已经超过你5级，无法获得经验", self:Name()))
        return
    end

    local mUpGrade = res["daobiao"]["upgrade"]
    local grades = extend.Table.keys(mUpGrade)
    local iMaxGrade = extend.Array.max(grades)
    -- local iMaxExp = mUpGrade[math.min(oPlayer:GetGrade() + 10, iMaxGrade)].summon_exp

    local iAddExp = 0
    mArgs = mArgs or {}
    if mArgs.bEffect then
        local iRatio = oPlayer.m_oStateCtrl:GetSummonExpRatio()
        iAddExp = math.ceil((iRewardExp * iRatio) / 100)
        iRewardExp = iRewardExp + iAddExp
    end

    local iExp = self:GetData("exp", 0)
    local iOldGrade = self:GetGrade()
    self:SetData("exp", iExp + iRewardExp)
    self:CheckUpGrade()

    self:PropChange("exp")
    local oToolMgr = global.oToolMgr
    local sMsg
    if iAddExp > 0 then
        sMsg = oToolMgr:FormatColorString("#summon获得了#exp经验, 服务器等级加成#exp", {summon = self:Name(), exp={iRewardExp, iAddExp}})    
    else
        sMsg = oToolMgr:FormatColorString("#summon获得了#exp经验", {summon = self:Name(), exp=iRewardExp})    
    end
    oChatMgr:HandleMsgChat(oPlayer, sMsg)

    local mLogData = self:LogData(oPlayer)
    mLogData["exp_old"] = iExp
    mLogData["exp_add"] = iRewardExp
    mLogData["grade_old"] = iOldGrade
    mLogData["exp_now"] = self:GetData("exp", 0)
    mLogData["reward_exp"] = iRewardExp
    mLogData["reason"] = sReason or "未知"
    record.log_db("summon", "exp", mLogData)
end

function CSummon:FullState()
    self:SetData("hp", self:GetMaxHP())
    self:SetData("mp", self:GetMaxMP())
end

function CSummon:CheckUpGrade()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    local mUpGrade = res["daobiao"]["upgrade"]
    local grades = extend.Table.keys(mUpGrade)
    local iMaxGrade = extend.Array.max(grades)

    local iOldGrade = self:Grade()
    for i=0, iMaxGrade do
        local m = mUpGrade[self:Grade() + 1]
        if not m then break end

        if self:Exp() < m.summon_exp then 
            break
        end

        if oPlayer and self:GetGrade() >= oPlayer:GetGrade() + 5 then
            break
        end

        self:SetData("exp", self:Exp()-m.summon_exp)
        self:UpGrade()
    end

    if iOldGrade ~= self:Grade() then
        if self:IsOpenAutoPoint() then
            self:AutoAssignPoint()
        end
        self:Setup()
        self:FullState()
        self:Refresh()
        self:PropChange("exp")
        self:PropChange("grade")
    end
end

function CSummon:UpGrade()
    self:SetData("grade", self:GetData("grade", 0) + 1)
    for _, attr in ipairs(summondefines.ATTRS) do
        self:AddAttribute(attr, 1)
    end
    self:Record()
    self:SetData("point", self:GetData("point", 0) + 5)
end

function CSummon:GetOwner()
    if self.m_Container then
        return self.m_Container:GetInfo("pid")
   end
end

function CSummon:Refresh()
    if self:GetOwner() then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:SetSummonPropChange(self:GetOwner(), self.m_iID, extend.Table.keys(PropHelperFunc))
    end
end

function CSummon:PropChange(...)
    local l = table.pack(...)
    local lNew = {}
    for _, k in pairs(l) do
        if PropHelperFunc[k] then
            table.insert(lNew, k)
        end
    end    
    if self:GetOwner() then
        local oWorldMgr = global.oWorldMgr
        oWorldMgr:SetSummonPropChange(self:GetOwner(), self.m_iID, lNew)
    end
end

function CSummon:ClientPropChange(oPlayer, m)
    local mInfo = self:SummonInfo(m)
    local oWorldMgr = global.oWorldMgr
    oPlayer:Send("GS2CSummonPropChange", {id=self.m_iID, summondata = mInfo})
end

function CSummon:SummonInfo(m)
    local mRet = {}
    if not m then
        m = PropHelperFunc
    end
    local iMask = 0
    for k, _ in pairs(m) do
        local f = assert(PropHelperFunc[k], string.format("SummonInfo fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.SummonInfo", mRet)
end

function CSummon:LogData(oPlayer)
    local mLog = {}
    if oPlayer then
        mLog = oPlayer:LogData()
    end

    local iTraceId = 0
    local mTrace = self:GetData("traceno")
    if mTrace then
        iTraceId = mTrace[2]
    end
    mLog["traceno"] = iTraceId
    mLog["sid"] = self:TypeID()
    mLog["slevel"] = self:Grade()
    mLog["sname"] = self:Name()
    return mLog
end

function CSummon:TraceRealNo()
    local mTrace = self:GetData("traceno")
    local iTraceId
    if mTrace then
        iTraceId = mTrace[2]
    end
    return iTraceId
end

function CSummon:DealLife(sGameplay, bDead)
    local iLife = 1
    if bDead and not summondefines.NOT_SUB_DEAD_LIFE[sGameplay] then
        iLife = 50
    end
    self:AddLife(-iLife)
end

function CSummon:LeaveWar(mData)
    local sGameplay = mData.gameplay
    if mData and mData.hp and mData.mp and sGameplay ~= "arena" then
        local iHP = mData.hp
        if iHP<=0 then
            iHP = self:GetMaxHP()
            -- self:AddLife(-50)
        else
            if mData.relife == true then
                iHP = self:GetMaxHP()
            end
            -- self:AddLife(-1)
        end
        self:DealLife(sGameplay, iHP<=0)
        iHP = math.min(iHP, self:GetMaxHP())
        self:SetData("hp", iHP)

        local iMP = mData.mp
        if iMP<=0 then
            iMP = self:GetMaxMP()
        else
            if mData.relife == true then
                iMP = self:GetMaxMP()
            end
        end
        iMP = math.min(iMP, self:GetMaxMP())
        self:SetData("mp", iMP)
        self:PropChange("mp","hp")
    end
    if mData.pid and not self:IsBind() then
        self:Bind(mData.pid)
    end

    local iWarType = mData.war_type
    self:DealBindRide(sGameplay, iWarType)
end

function CSummon:GetRankData()
    local mData = {}
    local iOwner , iTraceNo = table.unpack(self:GetData("traceno",{-1,-1}))
    iOwner = self:GetOwner()
    if iTraceNo == -1 then
        record.warning(string.format("sum_rank_err %s %s %s %s",iOwner,iTraceNo,self:GetOwner(),self:Name()))
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    local sOwnerName = "佚名"
    if oPlayer then
        sOwnerName = oPlayer:GetName()
    end
    mData.score = math.floor(self:GetScore())
    mData.key = string.format("%s_%s",math.floor(iOwner),math.floor(iTraceNo))
    mData.name = self:Name()
    mData.ownername = sOwnerName
    mData.typeid = self:TypeID()
    mData.pid = iOwner
    mData.basicinfo = self:SummonInfo()
    return mData
end

function CSummon:HasBindSkill()
    for _, oSkill in pairs(self.m_lSkills) do
        if oSkill:IsBind() then return true end
    end
    return false
end

function CSummon:Equip(oEquip)
    local oldEquip 
    for _, oEq in pairs(self.m_mEquip) do
        if oEq:EquipType() == oEquip:EquipType() then
            oldEquip = oEq
            break
        end
    end
 
    if oldEquip then
        self.m_mEquip[oldEquip:SID()] = nil
        oldEquip:EquipUnEffect(self)
        baseobj_safe_release(oldEquip)
    end
    self:Dirty()
    self.m_mEquip[oEquip:SID()] = oEquip
    oEquip:EquipEffect(self)
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
        if oPlayer then
            oPlayer:PropChange("score")
        end
    end
    if not self:IsBind() then
        self:Bind(self:GetOwner())
    end
    global.oScoreCache:SummonDirty(self:ID())
    self:PropChange("equipinfo", "score", "rank", "summon_score")
end

function CSummon:GetIsZhenPinState()
    if self:IsWild() then return false end

    return self:GetData("zhenpin", 0) > 0
end

function CSummon:CheckZhenPin()
    if self:GetData("zhenpin", 0) > 0 then
        return
    end
    if self:IsZhenPin() then
        self:SetData("zhenpin", 1)    
    end
end

function CSummon:GetZpMaxAptitude()
    local iRatio = 130/100
    if self:IsWild() or self:Type() == summondefines.TYPE_NORMALBB then
        iRatio = 125/100
    end
    local iMax = 0
    for _, aptitude in ipairs(summondefines.APTITUDES) do
        iMax = iMax + math.floor(self:BaseAptitude(aptitude) * iRatio)
    end
    return iMax
end

function CSummon:IsZhenPin()
    if self:IsWild() then return false end

    local iType = self:Type()
    if summondefines.IsImmortalBB(iType) then
        return true 
    end
    local mConfig = global.oSummonMgr:GetSummonConfig()
    if self:GetSKillCnt(true) >= mConfig["zp_skill_cnt"] then
        return true
    end
    local iCur, iMax = 0, self:GetZpMaxAptitude()
    local mCurAptitude = self:CurAptitude()
    for _, iVal in pairs(mCurAptitude) do
        iCur = iCur + iVal
    end
    if iMax <= 0 then return false end

    local iRate = 100
    for _,m in pairs(mConfig["zp_aptitude_rate"] or {}) do
        if m.grade > self:CarryGrade() then break end
       
        iRate = m.ratio
    end

    if (iCur / iMax) > (iRate/100) 
        and self:Grow() >= math.floor(self:BaseGrow()*mConfig["zp_grow"]/100) then
        return true
    end
    return false
end

function CSummon:GetWashCnt()
    return self:GetData("wash_cnt", 0)
end

function CSummon:SetWashCnt(iCnt)
    self:SetData("wash_cnt", iCnt)
end

function CSummon:PackAttrUnit(sAttr)
    local mNet = {}
    local iBase = self:GetBaseAttr(sAttr)
    local iRatio = self:QueryRatioApply(sAttr)
    mNet.base = iBase
    mNet.extra = self:QueryApply(sAttr) 
    mNet.ratio = iRatio 
    return mNet
end

function CSummon:PropSecondChange(sAttr)
    local sAttrUnit = gamedefines.SECOND_PROP_MAP[sAttr]
    if not sAttrUnit then return end

    self:PropChange(sAttrUnit)
end

function CSummon:AdvanceLevel()
    return self:GetData("advance_level", 0)
end

function CSummon:SetAdvanceLevel(iLevel)
    self:SetData("advance_level", iLevel)
end

function CSummon:SummonAdvance(iAdvance)
    local mConfig = global.oSummonMgr:GetAdvanceConfig(self:Type(), iAdvance)
    if not mConfig then return end

    local iGrow = mConfig["grow"]
    self:AddGrow(iGrow)
    self:SetAdvanceLevel(iAdvance)
    for _,sAttr in pairs(summondefines.APTITUDES) do
        local iAttribute = mConfig[sAttr]
        local mMaxAptitude = self:GetData("maxaptitude", {}) 
        local mCurAptitude = self:GetData("curaptitude", {})
        mMaxAptitude[sAttr] = mMaxAptitude[sAttr] + iAttribute
        mCurAptitude[sAttr] = mCurAptitude[sAttr] + iAttribute
        self:SetData("maxaptitude", mMaxAptitude)
        self:SetData("curaptitude", mCurAptitude)
    end
    if self:GetOwner() then
        global.oScoreCache:Dirty(self:GetOwner(), "summonctrl")
    end
    global.oScoreCache:SummonDirty(self:ID())
    self:CheckZhenPin()
    self:Setup()
    self:FullState()
    self:Refresh() 
    self:RefreshOwnerScore()
end

function CSummon:GetInitAttribute()
    local mInitAttribute = self:GetData("initaddattr", {})
        
    local iTotal = 0
    for sAttr, iVal in pairs(mInitAttribute) do
        iTotal = iTotal + iVal
    end
    if iTotal > 50 then
        return {}
    end
    return mInitAttribute
end

function CSummon:PackBackendInfo()
    local mData = {}
    mData.traceno = self:GetData("traceno")
    mData.sid = self:GetData("sid")
    mData.name = self:GetData("name")
    mData.grade = self:GetData("grade")
    mData.exp = self:GetData("exp")
    
    local mSkill = {}
    for _, oSkill in pairs(self.m_lSkills) do
        table.insert(mSkill, oSkill:Save())
    end
    mData.skills = mSkill

    local mSkill = {}
    for sk, oSkill in pairs(self.m_mTalents) do
        sk = db_key(sk)
        mSkill[sk] = oSkill:Save()
    end
    mData.talent = mSkill
    return mData
end

function CSummon:BindRide(iRide)
    self:SetData("bind_ride", iRide)
    self:PropChange("bind_ride")
end

function CSummon:UnBindRide()
    self:SetData("bind_ride", 0)
    self:PropChange("bind_ride")
end

function CSummon:GetBindRide()
    return self:GetData("bind_ride")
end

function CSummon:IsBindRide()
    local iRide = self:GetBindRide()
    if iRide and iRide > 0 then return true end

    return false
end

function CSummon:SetupControl()
    local iRide = self:GetBindRide()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then return end

    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if oRide and not oRide:IsExpire() then
        oRide:ControlEffect(self)
    end
end

function CSummon:AddControlSkill(iSkill)
    local oSkill = loadskill.NewSkill(iSkill)
    self.m_mControlSkill[iSkill] = oSkill
    oSkill:SkillEffect(self)
    -- global.oScoreCache:SummonDirty(self:ID())
    -- self:PropChange("summon_score") 
end

function CSummon:RemoveControlSkill()
    for _,oSkill in pairs(self.m_mControlSkill) do
        oSkill:SkillUnEffect(self)
        baseobj_safe_release(oSkill)
    end
    self.m_mControlSkill = {}
    -- global.oScoreCache:SummonDirty(self:ID())
    -- self:PropChange("summon_score")
end

function CSummon:DealBindRide(sGameplay, iWarType)
    local iRide = self:GetBindRide()
    if not iRide then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
        if oRide and not oRide:IsExpire() then
            oRide:OnLevelWar(sGameplay, iWarType)
        end
    end
end

function CSummon:IsRecord()
    return self.m_bRecord
end

function CSummon:Record()
    self.m_bRecord = true
end

function CSummon:UnRecord()
    self.m_bRecord = false
end

function CSummon:LogPlayerSummonInfo(oPlayer, iOperate)
    self:UnRecord()
    analylog.LogPlayerSummonInfo(oPlayer, self, iOperate)
end

function CSummon:GetServerGrade()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        return oPlayer:GetServerGrade()
    end
    return global.oWorldMgr:GetServerGrade()
end


