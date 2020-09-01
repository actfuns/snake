local res = require "data"
local tprint = require('extend').Table.print
local tserialize = require('extend').Table.serialize

function NewItemMgr(oPlayer)
    return CItemMgr:New(oPlayer)
end

local CItemMgr = {}
CItemMgr.__index = CItemMgr

function CItemMgr:New(oPlayer)
    local o = setmetatable({}, CItemMgr)
    o.m_oMaster = oPlayer
    return o
end

function CItemMgr:Init(lItemList)
    print("初始化 ItemMgr")
    self.m_mItemList = {}
    self.m_mEquipList = {}
    for idx, mItem in ipairs(lItemList) do
        if mItem.pos <= 100 then
            self.m_mEquipList[mItem.pos] = mItem
        else
            self.m_mItemList[mItem.pos] = mItem
        end
    end
end

function CItemMgr:AddEquip(mItem)
    self.m_mEquipList[mItem.pos] = mItem
end

function CItemMgr:AddItem(mItem)
    self.m_mItemList[mItem.pos] = mItem
end

function CItemMgr:GetItemByPos(iPos)
    return self.m_mItemList[iPos]
end

function CItemMgr:GetItemById(iItem)
    for iPos, mItem in pairs(self.m_mItemList) do
        if mItem.itemid == iItem then
            return iPos, mItem
        end
    end
end

function CItemMgr:GetItemAmountBySid(iSid)
    local iAmount = 0
    for iPos, mItem in pairs(self.m_mItemList) do
        if mItem.sid == iSid then
            iAmount = iAmount + mItem.amount
        end
    end
    return iAmount
end

function CItemMgr:GetItemListBySid(iSid)
    local lResult = {}
    for iPos, mItem in pairs(self.m_mItemList) do
        if mItem.sid == iSid then
            table.insert(lResult, {iPos, mItem.id, mItem.amount})
        end
    end
    return lResult
end

function CItemMgr:DelItemById(iItem)
    local iDel
    for iPos, mItem in pairs(self.m_mItemList) do
        if iItem == mItem.id then
            iDel = iPos
        end
    end
    if iDel then
        self.m_mItemList[iDel] = nil
        return
    end

    for iPos, mItem in pairs(self.m_mEquipList) do
        if iItem == mItem.id then
            iDel = iPos
        end
    end
    if iDel then
        self.m_mEquipList[iDel] = nil
    end
end

function CItemMgr:SetItemAmount(iItem, iAmount)
    for iPos, mItem in pairs(self.m_mItemList) do
        if iItem == mItem.id then
            mItem.amount = iAmount
        end
    end
end


local item = {}

item.GS2CLoignItem = function(self, mArgs)
    if not self.m_oItemMgr then
        self.m_oItemMgr = NewItemMgr(self)
    end
    self.m_oItemMgr:Init(mArgs.itemdata)
end

item.GS2CAddItem = function(self, mArgs)
    if mArgs.itemdata.pos <= 100 then
        self.m_oItemMgr:AddEquip(mArgs.itemdata)
    else
        self.m_oItemMgr:AddItem(mArgs.itemdata)
    end
end

item.GS2CDelItem = function(self, mArgs)
    local iItem = mArgs.id
    self.m_oItemMgr:DelItemById(iItem)
end

item.GS2CItemAmount = function(self, mArgs)
    local iItem = mArgs.id
    local iAmount = mArgs.amount
    if iAmount <= 0 then
        self.m_oItemMgr:DelItemById(iItem)
    else
        self.m_oItemMgr:SetItemAmount(iItem, iAmount)
    end
end

item.GS2CItemArrange = function(self, mArgs)
    local iItem = mArgs.itemid
    local iCurPos, mItem = self.m_oItemMgr:GetItemById(iItem)
    if not iCurPos then return end

    local iPos = mArgs.pos
    if iPos < 100 then
        self:DelItemById(iItem)
        self.m_mEquipList[iPos] = mItem
        mItem.pos = iPos
    else
        self:DelItemById(iItem)
        self.m_mItemList[iPos] = mItem
        mItem.pos = iPos
    end
end

return item
