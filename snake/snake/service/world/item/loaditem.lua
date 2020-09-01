local global = require "global"
local extend = require "base/extend"
local res = require "base.res"

local ItemDir = {
    ["virtual"]  = {1001,10000},
    ["other"]   = {10001,11999},
    ["fu"] = {12000,12099},
    ["shenhun"] = {12100,12299},
    ["shenhunfrag"] = {12300,12499},
    ["equipbook"] = {12600,12899},
    ["giftpack"] = {12900,13499},
    ["box"] = {13500,13599},
    ["wenshi"] = {13600,13699},
    ["equip"] = {21000,23000},
    ["partnerequip"] = {23001,23999},
    ["summon"] = {24000,24499},
    ["summonequip"] = {29000,29499},
    ["summskill"] = {30000,30599},
    ["partner"] = {30600, 30999},
    ["totask"] = {70000, 71999},
}

function NewItemLoader()
    return CItemLoader:New()
end

CItemLoader = {}
CItemLoader.__index = CItemLoader

function CItemLoader:New()
    local o = setmetatable({}, self)
    -- 缓存物品对象实例
    o.m_tmp_mItemList = {}
    return o
end

function CItemLoader:GetItemData(iSid)
    local mData = res["daobiao"]["item"]
    local mItemData = mData[iSid]
    assert(mItemData,string.format("GetItemData err:%s", iSid))
    return mItemData
end

function CItemLoader:GetBaseItemGroupData(iGroup)
    local mData = res["daobiao"]["itemgroup"]
    mData = mData[iGroup]
    assert(mData,string.format("GetItemGroup err:%d",iGroup))
    return mData
end

function CItemLoader:GetItemGroup(iGroup)
    local mData = self:GetBaseItemGroupData(iGroup)
    return mData["itemgroup"]
end

function CItemLoader:GetItemGroupName(iGroup)
    local mData = self:GetBaseItemGroupData(iGroup)
    return mData["name"]
end

function CItemLoader:GetItemDir(sid)
    for sDir,mPos in pairs(ItemDir) do
        local iStart,iEnd = table.unpack(mPos)
        if iStart <= sid and sid <= iEnd then
            return sDir
        end
    end
end

function CItemLoader:GetItemPath(sid)
    local sDir = self:GetItemDir(sid)
    if global.oDerivedFileMgr:ExistFile("item", sDir, "i"..sid) then
        return string.format("item/%s/i%d",sDir,sid)
    end
    return string.format("item/%s/%sbase",sDir,sDir)
end

function CItemLoader:RawCreate(sid)
    sid = tonumber(sid)
    assert(sid,string.format("loaditem Create err:%s",sid))
    if sid < 1000 then
        local mItemGroup = self:GetItemGroup(sid)
        sid = mItemGroup[math.random(#mItemGroup)]
    end
    local sPath = self:GetItemPath(sid)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("loaditem err:%d",sid))
    local oItem = oModule.NewItem(sid)
    return oItem
end

function CItemLoader:Create(sid, ...)
    local oItem = self:RawCreate(sid, ...)
    oItem:Create(...)
    oItem:Setup()
    return oItem
end

function CItemLoader:CreateFixedItem(sid, iFix, ...)
    local oItem = self:RawCreate(sid, ...)
    oItem:CreateFixedItem(iFix, ...)
    oItem:Setup()
    return oItem
end

function CItemLoader:ExtCreate(sid,...)
    local sArg
    if tonumber(sid) then
        sid = tonumber(sid)
    else
        sid,sArg = string.match(sid,"(%d+)(.*)")
        sid = tonumber(sid)
    end
    local oItem = self:RawCreate(sid, ...)
    oItem:Create(...)
    if sArg then
        sArg = string.sub(sArg,2,#sArg-1)
        local mArg = split_string(sArg,",")
        for _,sArg in ipairs(mArg) do
            local key,value = string.match(sArg,"(.+)=(.+)")
            key  = trim(key)
            if type(value) == "string" then
                value = trim(value)
            end
            if tonumber(value) then
                value = tonumber(value)
            end
            local sAttr = string.format("m_i%s",key)
            if oItem[sAttr] then
                oItem[sAttr] = value
            else
                oItem:SetData(key,value)
            end
        end
    end
    oItem:Setup()
    return oItem
end

function CItemLoader:GetItemNameBySid(sid)
    local mItemData = self:GetItemData(sid)
    return mItemData.name
end

function CItemLoader:GetItemTipsNameBySid(sid)
    local mItemData = self:GetItemData(sid)
    local sName =  mItemData.name
    local iColor = mItemData.quality
    local mItemColor = res["daobiao"]["itemcolor"][iColor]
    assert(iColor, mItemColor, string.format("item color config not exist! id:", iColor))
    return string.format(mItemColor.color, sName)
end

function CItemLoader:GetItem(sid)
    local oItem = self.m_tmp_mItemList[sid]
    if not oItem then
        oItem = self:RawCreate(sid)
        self.m_tmp_mItemList[sid] = oItem
    end
    return oItem
end

function CItemLoader:HasItemData(iSid)
    local sDir = self:GetItemDir(iSid)
    return table_get_depth(res, {"daobiao", "item", iSid})
end

function CItemLoader:HasItemModule(iSid)
    local sPath = self:GetItemPath(iSid)
    return import(service_path(sPath))
end

function CItemLoader:HasItem(iSid)
    return self:HasItemData(iSid) and self:HasItemModule(iSid)
end

function CItemLoader:LoadItem(sid,data)
    sid = tonumber(sid)
    assert(sid,string.format("loaditem LoadItem err:%s",sid))
    local sPath = self:GetItemPath(sid)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("loaditem err:%d",sid))
    local oItem = oModule.NewItem(sid)
    oItem:Load(data)
    oItem:Setup()
    return oItem
end

function CItemLoader:CloneItem(oItem, iToPlayerId)
    return oItem:Clone(iToPlayerId)
end
