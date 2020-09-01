local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local itembase = import(service_path("item/other/otherbase"))
local itemdefines = import(service_path("item.itemdefines"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,itembase.CItem)

function CItem:New(sid)
    local o = super(CItem).New(self,sid)
    return o
end

function CItem:Create(mArgs)
    super(CItem).Create(self,mArgs)
    mArgs = mArgs or {}
    local iLevel = mArgs.skill_level or 1
    self:SetData("skill_level",iLevel)
end

function CItem:ApplyInfo()
    local mData = {}
    table.insert(mData,{key="skill_level",value =self:GetData("skill_level",1) })
    return mData
end

function CItem:TrueUse(oPlayer, iTarget, iCostAmount, mArgs)
    if oPlayer:InWar() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),"战斗中无法使用")
        return 
    end
    local mRes = res["daobiao"]["skill"]["fuzhuanitem"]
    local itemsid = self:SID()
    assert(mRes[itemsid],string.format("%s use error",itemsid))
    local iSkill = mRes[itemsid]
    local mConfigData = res["daobiao"]["skill"][iSkill]
    local iEquipPos = mConfigData["equip_pos"]
    local sAttr = mConfigData["attr"]
    local sAttrValue = mConfigData["attr_value"]
    local iLevel = self:GetData("skill_level",1)
    local iAttrValue = formula_string(sAttrValue,{lv=iLevel})
    iAttrValue = math.floor(iAttrValue)
    local oEquip = oPlayer.m_oItemCtrl:GetItem(iEquipPos)
    if not oEquip then
        local sText = global.oToolMgr:GetTextData(1014,{"skill"})
        local sEquipName = itemdefines.GetEquipName(iEquipPos) or ""
        sText = global.oToolMgr:FormatColorString(sText,{equipPos = sEquipName})
        global.oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        return
    end
    local mAttr = {}
    mAttr[sAttr] = iAttrValue
    oEquip:SetFuZhuanAttr(mAttr)
    oPlayer:RefreshPropAll()
    oPlayer:RemoveOneItemAmount(self, 1, "fuzhuan")
end