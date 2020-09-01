local global = require "global"
local extend = require "base/extend"
local res = require "base.res"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))

local GROW_FINISH = 1
local GROW_REWARD = 1
local GROW_REWARDED = 2

function NewGrow(...)
    return CGrow:New(...)
end

CGrow = {}
CGrow.__index = CGrow
inherit(CGrow, datactrl.CDataCtrl)

function CGrow:New(pid)
    local o = super(CGrow).New(self, {pid = pid})
    self.m_mGrow = {}
    return o
end

function CGrow:OnLogin(oPlayer,bReEnter)
    self:SendAllGrowInfo()
end

function CGrow:Save()
    local mData = {}
    mData.growinfo = table_to_db_key(self.m_mGrow)
    return mData
end

function CGrow:Load(mData)
    mData = mData or {}
    self.m_mGrow = table_to_int_key(mData.growinfo or {})
end

function CGrow:GetRes()
    return res["daobiao"]["huodong"]["grow"]["config"]
end

function CGrow:MarkGrow(index)
    local mRes = self:GetRes()
    local mInfo = mRes[index]
    if not mInfo then
        record.warning(string.format("MarkGrow index error %s %s",self:GetInfo("pid",0),index))
        return
    end
    local iLevelIndex = mInfo.level_index
    local iLevel = mInfo.level
    if not self.m_mGrow[index] then
        self.m_mGrow[index] = {}
    end

    local mData = self.m_mGrow[index]
    if mData["finish"] == GROW_FINISH then
        return
    end
    self:Dirty()
    mData["finish"] = GROW_FINISH
    mData["reward"] = GROW_REWARD
    self.m_mGrow[index]  = mData
    self:Refresh(index)
end

function CGrow:GiveReward(oPlayer,index)
    if is_ks_server() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),"跨服暂未开放此功能")
        return
    end
    local mRes = self:GetRes()
    local mInfo = mRes[index]
    if not mInfo then
        record.warning(string.format("MarkGrow index error %s %s",self:GetInfo("pid",0),index))
        return
    end


    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not self.m_mGrow[index] then
        oNotifyMgr:Notify(pid,self:GetTextData(1001))
        return
    end
    local mData = self.m_mGrow[index]
    if mData["finish"] ~= GROW_FINISH then
        oNotifyMgr:Notify(pid,self:GetTextData(1001))
        return
    end
    if mData["reward"] == GROW_REWARDED then
        oNotifyMgr:Notify(pid,self:GetTextData(1002))
        return
    end
    if mData["reward"] ~= GROW_REWARD then
        oNotifyMgr:Notify(pid,self:GetTextData(1001))
        return
    end

    local sHD = "grow"
    local iReward = mInfo["reward"]
    local iHaveSpace = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iHaveSpace<=0 then
        if global.oToolMgr:HasTrueItemByReward(sHD,iReward) then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),"你的背包已满，请清理后再领取")
            return
        end
    end
    self:Dirty()
    mData["reward"] = GROW_REWARDED
    local oHD = global.oHuodongMgr:GetHuodong(sHD)
    oHD:Reward(pid,iReward)
    self:Refresh(index)
end

function CGrow:ClearAll()
    self:Dirty()
    self.m_mGrow = {}
    self:SendAllGrowInfo()
end

function CGrow:GetTextData(iText)
    local oHD = global.oHuodongMgr:GetHuodong("grow")
    return oHD:GetTextData(iText)
end

function CGrow:Refresh(index)
    local pid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mNet = {}
    local mData = self.m_mGrow[index]
    mNet.index = index
    mNet.reward = mData["reward"]
    mNet.finish = mData["finish"]
    oPlayer:Send("GS2CRefreshGrow",mNet)
    --print("GS2CRefreshGrow",mNet)
end

function CGrow:SendAllGrowInfo()
    local pid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mNet = {}
    local mGrowInfo  =  {}
    for iIndex,mInfo in pairs(self.m_mGrow) do
        local mData = {}
        mData.index = iIndex
        mData.finish = mInfo.finish
        mData.reward = mInfo.reward
        table.insert(mGrowInfo,mData)
    end
    mNet.growinfo = mGrowInfo
    oPlayer:Send("GS2CAllGrowInfo",mNet)
    --print("GS2CAllGrowInfo",mNet)
end
