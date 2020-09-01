local global = require "global"
local skynet = require "skynet"

local datactrl = import(lualib_path("public.datactrl"))

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end

CItem = {}
CItem.__index = CItem
inherit(CItem,datactrl.CDataCtrl)

function CItem:New(sid)
    local o = super(CItem).New(self)
    o.m_SID = sid
    return o
end

function CItem:Init(mSaveData)
    assert(mSaveData,string.format("%s init error",self.m_SID))
    assert(mSaveData["sid"],string.format("%s init sid error",self.m_SID))
    assert(mSaveData["create_time"],string.format("%s init create_time error",self.m_SID))
    self.m_ID = self:DispatchItemID()
    self.m_SaveData = mSaveData
    self.m_mData = self.m_SaveData["data"] or {}
    self.m_SID = self.m_SaveData["sid"]
end

function CItem:Load(mData)
    if not mData then
        return
    end
    self:Init(mData)
end

function CItem:Save()
    self.m_SaveData["data"] = self.m_mData or {}
    return self.m_SaveData
end

function CItem:GetItemData()
    local res = require "base.res"
    local mData = res["daobiao"]["item"]
    local mItemData = mData[self.m_SID]
    assert(mItemData,string.format("itembase GetItemData err:%s",self.m_SID))
    return mItemData
end

function CItem:DispatchItemID()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:DispatchItemID()
end

function CItem:ID()
    return self.m_ID
end

function CItem:SID()
    return self.m_SID
end

function CItem:Name()
    return self:GetItemData()["name"]
end

function CItem:GetAmount()
    return self.m_SaveData["amount"] or 1
end

function CItem:GetGrade()
    local iQuality = self:GetData("equip_level")
    if iQuality then
        return iQuality
    end
    local mItemData = global.oItemLoader:GetItemData(self:SID())
    return mItemData.quality or 1
end

function CItem:GetCreateTime()
    return self.m_SaveData["create_time"] or 0
end

function CItem:PackInfo()
    local mNet = {}
    mNet.id = self.m_ID
    mNet.sid = self.m_SID
    mNet.pos = self.m_Pos
    mNet.amount = self:GetAmount()
    return mNet
end