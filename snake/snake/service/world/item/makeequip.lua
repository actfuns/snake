local global = require "global"
local extend = require "base/extend"

local loadskill = import(service_path("skill/loadskill"))

function GetEquipLevelData()
    local res = require "base.res"
    return res["daobiao"]["equiplevel"]
end

function GetEquipAttrData()
    local res = require "base.res"
    return res["daobiao"]["equipattr"]
end

function GetEquipFixedData()
    local res = require "base.res"
    return res["daobiao"]["equipfixed"]
end

function GetSeData()
    local res = require "base.res"
    return res["daobiao"]["equipse"]
end

function GetSKData()
    local res = require "base.res"
    return res["daobiao"]["equipsk"]
end

function GetEquipGlobal()
    local res = require "base.res"
    return res["daobiao"]["equipglobal"][1] 
end

CEquipMakeMgr = {}
CEquipMakeMgr.__index = CEquipMakeMgr
inherit(CEquipMakeMgr, logic_base_cls())

--随机品质
function CEquipMakeMgr:EquipRandLevel()
    local mData = GetEquipLevelData()
    local iRnd = math.random(100)
    local iRatio = 0
    for _,mLevelData in pairs(mData) do
        iRatio = iRatio + mLevelData["ratio"]
        if iRatio >= iRnd then
            return mLevelData["id"]
        end
    end
    return 1
end

--打造品质
function CEquipMakeMgr:MakeRandLevel()
    local mData = GetEquipLevelData()
    local iRnd = math.random(100)
    local iRatio = 0
    for _,mLevelData in pairs(mData) do
        iRatio = iRatio + mLevelData["makeRatio"]
        if iRatio >= iRnd then
            return mLevelData["id"]
        end
    end
    assert(nil, "equip dazao rand lv missmatch ratio:" .. iRatio)
end

function CEquipMakeMgr:CalculateKArea(oEquip)
    local iLevel = oEquip:GetData("equip_level",1)
    local mData = GetEquipLevelData()
    local mLevelData = mData[iLevel]
    return mLevelData["min"], mLevelData["max"]
end

--计算波动系数
function CEquipMakeMgr:CalculateK(oEquip)
    local iMinRatio, iMaxRatio = self:CalculateKArea(oEquip)
    local iK = math.random(iMinRatio, iMaxRatio)
    return iK
end

function CEquipMakeMgr:MakeEquip(oEquip,mArgs)
    mArgs = mArgs or {}
    local iEquipLevel = mArgs.equip_level
    local iSchool = mArgs.school
    local bMake = mArgs.equip_make
    if not iEquipLevel then
        if not bMake then
            iEquipLevel = self:EquipRandLevel()
        else
            iEquipLevel = self:MakeRandLevel()
        end
    end
    oEquip:SetData("equip_level",iEquipLevel)
    if mArgs.growlevel then
        oEquip.m_iGrowLevel = mArgs.growlevel
    end
    self:CalculateApply(oEquip)

    if bMake then
        oEquip:SetData("is_make", 1)
        oEquip:SetData("last", 500)
        self:CalculateSE(oEquip,mArgs)
        self:CalculateSK(oEquip,mArgs)
    end
end

function CEquipMakeMgr:MakeFixedEquip(oEquip, iFix, mArgs)
    local mData = GetEquipFixedData()[iFix]
    assert(mData, string.format("not find equip fixed id:%s", iFix))

    if mData["make"] then
        oEquip:SetData("is_make", 1)
    end
    local iRatio = mData["attr_ratio"]
    local iQuality = self:CalQuality(iRatio)
    oEquip:SetData("equip_level", iQuality)
    self:CalculateApply(oEquip, iRatio)

    local iEquipLevel = oEquip:EquipLevel()
    local iEquipPos = oEquip:EquipPos()
    for _, iSE in pairs(mData["se_skill"]) do
        local oSE = loadskill.NewSkill(iSE)
        oSE:SetPos(iEquipPos)
        oSE:SetLevel(iEquipLevel)
        oEquip:AddSE(oSE)
    end
    for _, iSK in pairs(mData["sk_skill"]) do
        local oSK = loadskill.NewSkill(iSK)
        oSK:SetLevel(iEquipLevel)
        oEquip:AddSK(oSK)
    end
end

function CEquipMakeMgr:CalculateApply(oEquip, iRatio)
    local iPos = oEquip:EquipPos()
    local mData = GetEquipAttrData()
    local mAttrData = mData[iPos]["attr"]
    local mEnv = {
        ilv = oEquip:EquipLevel(),
    }
    -- 每次计算独立的波动系数
    -- local mVariK = {}
    for _,sAttr in pairs(mAttrData) do
        local sKey,iValue = string.match(sAttr,"(.+)=(.+)")
        iValue = formula_string(iValue, mEnv)
        if iRatio then
            iValue = iValue * iRatio / 100
        else
            local iMin, iMax = self:CalculateKArea(oEquip)
            iMin, iMax = math.floor(iValue * iMin / 100), math.floor(iValue * iMax / 100)
            iValue = math.random(iMin, iMax)    
        end
        -- iValue = math.floor(iValue)
        oEquip:AddApply(sKey,iValue)
        -- mVariK[sKey] = iK
    end
    local mAttrData = mData[iPos]["attrRatio"]
    for _,sAttr in pairs(mAttrData) do
        local iK = self:CalculateK(oEquip)
        local sKey,iValue = string.match(sAttr,"(.+)=(.+)")
        iValue =formula_string(iValue,mEnv)
        iValue = iValue * iK / 100
        -- iValue = math.floor(iValue)
        oEquip:AddRatioApply(sKey,iValue)
        -- mVariK[sKey] = iK
    end

    -- oEquip:SetK(mVariK)
end

function CEquipMakeMgr:CalLevelUpApply(oEquip, iOldLevel, iNewLevel)
    local iPos = oEquip:EquipPos()
    local mData = GetEquipAttrData()
    local mAttrData = mData[iPos]["attr"]
    local mMinEnv = {
        ilv = iOldLevel,
    }
    local mMaxEnv = {
        ilv = iNewLevel,    
    }
    -- 装备升级属性变化
    for _,sAttr in pairs(mAttrData) do
        local sKey,sValue = string.match(sAttr,"(.+)=(.+)")
        local iMinValue = formula_string(sValue, mMinEnv)
        local iMaxValue = formula_string(sValue, mMaxEnv)
        local iValue = oEquip:GetApply(sKey)   
        iValue = iValue * math.max(iMaxValue/iMinValue, 1) 
        oEquip:AddApply(sKey,iValue)
    end
    local mAttrData = mData[iPos]["attrRatio"]
    for _,sAttr in pairs(mAttrData) do
        local sKey,sValue = string.match(sAttr,"(.+)=(.+)")
        local iMinValue = formula_string(sValue, mMinEnv)
        local iMaxValue = formula_string(sValue, mMaxEnv)
        local iValue = oEquip:GetRatioApply(sKey)   
        iValue = iValue * math.max(iMaxValue/iMinValue, 1) 
        oEquip:AddRatioApply(sKey,iValue)
    end
end

function CEquipMakeMgr:GetSelectSEMap(iLevel, iPos, mExclude)
    local mSeData = GetSeData()
    local mData = table_get_depth(mSeData, {iLevel, iPos})
    if not mData then return {} end

    local mSelect = {}
    mExclude = mExclude or {}
    for _, mInfo in pairs(mData) do
        if not mExclude[mInfo.se] then
            mSelect[mInfo.se] = mInfo.ratio
        end
    end
    return mSelect
end

function CEquipMakeMgr:CalculateSERatio(oEquip, mArgs)
    local iRatio = 0
    if mArgs.se_ratio then
        iRatio = mArgs.se_ratio
    else
        local sFormula = GetEquipGlobal()["cal_se_ratio"]
        iRatio = formula_string(sFormula, {lv = oEquip:EquipLevel()})
    end
    return math.floor(iRatio)
end

--计算特效
function CEquipMakeMgr:CalculateSE(oEquip, mArgs)
    local iEquipLevel = oEquip:EquipLevel()
    local iEquipPos = oEquip:EquipPos()
    local mSelect = self:GetSelectSEMap(iEquipLevel, iEquipPos)
    local iRatio = self:CalculateSERatio(oEquip, mArgs)

    if next(mSelect) and math.random(100) <= iRatio then
        local iSE = table_choose_key(mSelect)
        local oSE = loadskill.NewSkill(iSE)
        oSE:SetPos(iEquipPos)
        oSE:SetLevel(iEquipLevel)
        oEquip:AddSE(oSE)
    end

    mSelect = self:GetSelectSEMap(iEquipLevel, 99)
    if next(mSelect) and math.random(100) <= iRatio then
        local iSE = table_choose_key(mSelect)
        local oSE = loadskill.NewSkill(iSE)
        oSE:SetPos(iEquipPos)
        oSE:SetLevel(iEquipLevel)
        oEquip:AddSE(oSE)
    end
end

function CEquipMakeMgr:CalculateSKRatio(oEquip, mArgs)
    local iRatio = 0
    if mArgs.sk_ratio then
        iRatio = mArgs.sk_ratio
    else
        for _, mData in pairs(GetEquipGlobal()["cal_sk_ratio"]) do
            if mData["level"] > oEquip:EquipLevel() then
                break
            end
            iRatio = mData["ratio"]
        end
    end
    return math.floor(iRatio)
end

function CEquipMakeMgr:CalculateSK(oEquip, mArgs)
    local mSKData = GetSKData()
    local iEquipLevel = oEquip:EquipLevel()
    local mData = mSKData[iEquipLevel]
    if not mData then
        return
    end
    local iRatio = self:CalculateSKRatio(oEquip, mArgs)
    if mArgs.sk_ratio then
        iRatio = mArgs.sk_ratio
    end
    if math.random(100) <= iRatio then
        local mRatio = {}
        for _,mInfo in pairs(mData) do
            local iSK = mInfo["sk"]
            local iRatio = mInfo["ratio"]
            mRatio[iSK] = iRatio
        end
        local iSK = table_choose_key(mRatio)
        local oSK = loadskill.NewSkill(iSK)
        oSK:SetLevel(iEquipLevel)
        oEquip:AddSK(oSK)
    end
end

function CEquipMakeMgr:CalQuality(iRatio)
    local mData = GetEquipLevelData()
    local iMin, iMax 
    for iQuality, m in pairs(mData) do
        if m["min"] <= iRatio and iRatio <= m["max"] then
            return iQuality
        end
        if not iMin or iMin > m["min"] then
            iMin = m["min"]
        end
        if not iMax or iMax < m["max"] then
            iMax = m["max"]
        end
    end
    if iMin > iRatio then return 1 end

    if iMax < iRatio then return 4 end
    return 1
end
