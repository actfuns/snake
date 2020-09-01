--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))

local MAX_LOG_NUM = 200

function NewLogMgr(...)
    return COrgLogMgr:New(...)
end

COrgLogMgr = {}
COrgLogMgr.__index = COrgLogMgr
inherit(COrgLogMgr, datactrl.CDataCtrl)

function COrgLogMgr:New(orgid)
    local o = super(COrgLogMgr).New(self, {orgid = orgid})
    o.m_lHistory = {}
    o.m_iHistoryID = 0
    return o
end

function COrgLogMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgLogMgr:Load(mData)
    mData = mData or {}
    self.m_iHistoryID = mData.historyid or 0
    if mData.historys then
        local lHistory = {}
        for _, v in pairs(mData.historys) do
            table.insert(lHistory, v)
        end
        self.m_lHistory = lHistory
    end
end

function COrgLogMgr:Save()
    local mData = {}
    mData.historyid = self.m_iHistoryID
    local lHistory = {}
    for _, v in pairs(self.m_lHistory) do
        table.insert(lHistory, v)
    end
    mData.historys = lHistory
    return mData
end

function COrgLogMgr:DispatchID()
    self:Dirty()
    self.m_iHistoryID = self.m_iHistoryID + 1
    return self.m_iHistoryID
end

function COrgLogMgr:AddHistory(iPid, sMsg)
    self:Dirty()
    local id = self:DispatchID()
    local iTime = get_time()
    local tHis = {iPid, iTime, sMsg, id}

    table.insert(self.m_lHistory, 1, tHis)
    self:SortHistoryLog()
    if #self.m_lHistory > MAX_LOG_NUM then
        table.remove(self.m_lHistory, #self.m_lHistory)
    end
    self:GS2CAddHistoryLog(tHis)
end

function COrgLogMgr:GS2CAddHistoryLog(tHis)
    if not tHis then return end

    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendGS2Org(self:GetInfo("orgid"), "GS2CAddHistoryLog", {info=self:PackHisInfo(tHis)})
end

function COrgLogMgr:SortHistoryLog()
    table.sort(self.m_lHistory, function (h1, h2)
        return h1[2] > h2[2]
    end)
end

function COrgLogMgr:PackHistoryListInfo()
    local mNet, iCnt = {}, 1
    for _, tHis in pairs(self.m_lHistory) do
        table.insert(mNet, self:PackHisInfo(tHis))

        iCnt = iCnt + 1
        if iCnt > 10 then break end
    end
    return mNet
end

function COrgLogMgr:PackHisInfo(tHis)
    local mNet = {}
    mNet["time"] = tHis[2]
    mNet["text"] = tHis[3]
    mNet["logid"] =tHis[4]
    return mNet
end

function COrgLogMgr:GS2CNextPageLog(oPlayer, iLastId)
    local mNet, iCnt = {}, 0
    for _, tHis in pairs(self.m_lHistory) do
        if iCnt > 0 then
            table.insert(mNet, self:PackHisInfo(tHis))

            iCnt = iCnt + 1
            if iCnt > 10 then break end
        end

        if tHis[4] == iLastId then
            iCnt = 1
        end
    end
    oPlayer:Send("GS2CNextPageLog", {infos=mNet})
end

