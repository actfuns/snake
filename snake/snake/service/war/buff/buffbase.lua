--import module

local global = require "global"
local skynet = require "skynet"

lPackAttr = {"phy_defense", "mag_defense", "phy_attack", "mag_attack", "speed"}

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, logic_base_cls())

function CBuff:New(id)
    local o = super(CBuff).New(self)
    o.m_ID = id
    o.m_mSet = {}
    o.m_iStack = 0
    return o
end

function CBuff:Init(iBout,mArgs)
     self.m_iBout = iBout
     self.m_mArgs = mArgs
end

function CBuff:GetBuffData()
    local res = require "base.res"
    local mData = res["daobiao"]["buff"][self.m_ID]
    assert(mData, string.format("buff id err: %d", self.m_ID))
    return mData
end

function CBuff:BuffId()
    return self.m_ID
end

function CBuff:Name()
    local mData = self:GetBuffData()
    return mData["name"]
end

function CBuff:Type()
    local mData = self:GetBuffData()
    return mData["type"]
end

function CBuff:GroupType()
    local mData = self:GetBuffData()
    return mData["groupType"]
end

function CBuff:BuffType()
    local mData = self:GetBuffData()
    return mData["buffType"]
end

--叠加或者替换
function CBuff:UpdateType()
    local mData = self:GetBuffData()
    return mData["updateType"]
end

function CBuff:AttrRatioList()
    local mData = self:GetBuffData()
    return mData["attr_ratio_list"] or {}
end

function CBuff:AttrValueList()
    local mData = self:GetBuffData()
    return mData["attr_value_list"] or {}
end

function CBuff:AttrTempRatio()
    local mData = self:GetBuffData()
    return mData["attr_temp_ratio"]
end

function CBuff:AttrTempAddValue()
    local mData = self:GetBuffData()
    return mData["attr_temp_addvalue"]
end

function CBuff:AttrMask()
    local mData = self:GetBuffData()
    return mData["attr_set"]
end

function CBuff:CalAttrValue(sFormula)
    local mEnv = {
        level = self:PerformLevel(),
        grade = self:ActionGrade(),
    }
    local iValue = math.floor(formula_string(sFormula, mEnv))
    return iValue
end

function CBuff:SetAttr(key,value)
    self.m_mSet[key] = value
end

function CBuff:GetAttr(key)
    return self.m_mSet[key]
end

function CBuff:GetSetAttr()
    return self.m_mSet or {}
end

function CBuff:PerformLevel()
    return self.m_mArgs["level"] or 0
end

function CBuff:ActionWid()
    -- 释放者
    return self.m_mArgs["action_wid"] or 0
end

function CBuff:ActionGrade()
    return self.m_mArgs["grade"] or 0
end


function CBuff:CalInit(oAction,oBuffMgr)
end

function CBuff:OnRemove(oAction,oBuffMgr)
    local mFunc = oAction:GetFunction("OnBuffRemove")
    for _, func in pairs(mFunc) do
        func(self, oAction, oBuffMgr)
    end
end

function CBuff:OnNewBout(oAction,oBuffMgr)
end

function CBuff:OnBoutEnd(oAction,oBuffMgr)
    -- body
end

function CBuff:Bout()
    return self.m_iBout
end

function CBuff:AddBout(iBout)
    self.m_iBout = self.m_iBout + iBout
end

function CBuff:SetBout(iBout)
    self.m_iBout = iBout
end

function CBuff:SubBout(iBout)
    if self.m_iBout == 99 then
        return
    end
    iBout = iBout or 1
    self.m_iBout = self.m_iBout - iBout
end

function CBuff:GetStack()
    return self.m_iStack
end

function CBuff:AddStack(iCnt)
    if iCnt <= 0 then return end

    self.m_iStack = math.min(self:MaxStack(), self.m_iStack + iCnt)
end

function CBuff:SubStack(iCnt)
    if iCnt <= 0 then return end

    self.m_iStack = math.max(0, self.m_iStack - iCnt)
end

function CBuff:MaxStack()
    return 999
end

function CBuff:PackAttr(oAction)
    if not oAction then return {} end

    local lAttr = {}
    for _, sKey in ipairs(lPackAttr) do
        local mUnit = {}
        mUnit.key = sKey
        mUnit.value = oAction.m_oBuffMgr:GetAttrBaseRatioByBuff(sKey, self.m_ID)
        table.insert(lAttr, mUnit)
    end
    return lAttr
end

function CBuff:Refresh(oAction)
    if not oAction then
        return
    end
    local oWar = oAction:GetWar()
    if not  oWar then 
        return 
    end
    oAction:SendAll("GS2CWarBuffBout", {
        war_id = oWar:GetWarId(),
        wid = oAction:GetWid(),
        buff_id = self.m_ID,
        bout  = self:Bout(),
        stack = self:GetStack(),
        attrlist = self:PackAttr(oAction),
    })
end

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end
