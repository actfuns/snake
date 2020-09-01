local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"
local res = require "base.res"

local itembase = import(service_path("item/other/otherbase"))

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)
CItem.m_ItemType = "wenshi"


function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

function CItem:Init(sid)
    super(CItem).Init(self, sid)
    self.m_lApply = {}
end

function CItem:Save()
    local mData = super(CItem).Save(self)
    mData.applylist = self.m_lApply
    return mData
end

function CItem:Load(mData)
    super(CItem).Load(self,mData)
    self.m_lApply = mData.applylist or {} 
end

function CItem:Create(mArgs)
    mArgs = mArgs or {}
    self:SetData("growlevel", mArgs.level or 1)
    self:SetData("last", mArgs.last or self:GetMaxLast())
    self:MakeAttr()
end

function CItem:WenShiType()
    return self:GetItemData()["wenshi_type"]
end

function CItem:GrowLevel()
    return self:GetData("growlevel", 1)
end

function CItem:GetLast()
    return self:GetData("last", 0)
end

function CItem:AddLast(iVal)
    iVal = iVal + self:GetLast()
    iVal = math.min(math.max(iVal, 0), self:GetMaxLast()) 
    self:SetData("last", iVal)
end

function CItem:GetApplys()
    if self:GetLast() <= 0 then return {} end

    local mApply = {}
    for _,mAttr in pairs(self.m_lApply) do
        for k,v in pairs(mAttr) do
            mApply[k] = v + (mApply[k] or 0)
        end
    end
    return mApply
end


function CItem:HasMakeAttr()
    if #self.m_lApply > 0 then return true end

    return false
end

function CItem:MakeAttr()
    self.m_lApply = {}
    for i = 1, self:GetAttrCnt() do
        local mAttr = self:RandomAttr()
        table.insert(self.m_lApply, mAttr)
    end
    self:Dirty()
end

function CItem:SetAttr(mAttr)
    table.insert(self.m_lApply, mAttr)
    self:Dirty()
end

function CItem:GetAttrByIndex(iIdx)
    return self.m_lApply[iIdx]
end

function CItem:RandomAttr()
    local iIdx = self:RandomAttrIndex()
    local mConfig = self:GetAttrConfigByIndex(iIdx)
    local sKey = mConfig.attr_key
    local iValue = mConfig.attr_val
    return {[sKey]=iValue}
end

function CItem:WashAttr(lWashIndex)
    for _,iIdx in pairs(lWashIndex) do
        local mAttr = self:RandomAttr()
        table.remove(self.m_lApply, iIdx)
        table.insert(self.m_lApply, iIdx, mAttr)
    end
    self:Dirty()
end

function CItem:PackEquipInfo()
    local lApply = {}
    for _,m in pairs(self.m_lApply) do
        for k,v in pairs(m) do
            table.insert(lApply, {
                key = k,
                value = v*100,
            })
        end
    end
    return {
        last = self:GetLast(),
        attach_attr = lApply,
        grow_level = self:GrowLevel(),
        score = self:GetScore(),   
    }
end

function CItem:GetScore()
    return self:GetGradeConfig()["score"] or 0
end

function CItem:PackItemInfo()
    local mNet = super(CItem).PackItemInfo(self)
    mNet.equip_info = self:PackEquipInfo()
    return mNet
end

function CItem:DeComposeItems()
    local mGiveItem = {}
    local mConfig = self:GetColorConfig()["decompose_got"]
    for _,v in pairs(mConfig) do
        if v.level == self:GrowLevel() then
            mGiveItem[v.sid] = v.cnt    
        end
    end
    return mGiveItem
end

function CItem:Quality(bArrange)
    -- TODO 
    if not bArrange then
        return super(CItem).Quality(self,bArrange)
    end
    return self:GrowLevel()
end

-------------config---------------------
function CItem:GetMaxLast()
    local mConfig = self:GetGradeConfig()
    return mConfig["last"]
end

function CItem:GetMaxGrowLevel()
    local mConfig = res["daobiao"]["wenshi"]["grade_config"]
    local lGrade = table_key_list(mConfig)
    return math.max(table.unpack(lGrade))
end

function CItem:GetAttrCnt()
    local mConfig = self:GetGradeConfig()
    return mConfig["attr_cnt"]
end

function CItem:RandomAttrIndex()
    local mConfig = self:GetColorConfig()
    local mRatio = {}
    for _,v in pairs(mConfig.attr_weight) do
        mRatio[v.id] = v.weight
    end
    return table_choose_key(mRatio) 
end

function CItem:GetWashCost()
    local mConfig = self:GetColorConfig()["wash_cost"]
    for _,v in pairs(mConfig) do
        if v.level == self:GrowLevel() then
            return {[v.sid] = v.cnt}
        end
    end
end

function CItem:GetColorConfig()
    return res["daobiao"]["wenshi"]["color_config"][self:WenShiType()]
end

function CItem:GetGradeConfig(iGrowLevel)
    iGrowLevel = iGrowLevel or self:GrowLevel()
    return res["daobiao"]["wenshi"]["grade_config"][iGrowLevel]
end

function CItem:GetAttrConfigByIndex(iIdx)
    return res["daobiao"]["wenshi"]["attr_list"][iIdx]
end




