--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"
local record = require "public.record"
local cjson = require "cjson"
local res = require "base.res"
local router = require "base.router"

local serverinfo = import(lualib_path("public.serverinfo"))
local gamedb = import(lualib_path("public.gamedb"))


function NewBackendMgr(...)
    local o = CBackendMgr:New(...)
    return o
end

CBackendMgr = {}
CBackendMgr.__index = CBackendMgr
CBackendMgr.sDbKey = "backendinfo"

function CBackendMgr:New()
    local o = setmetatable({}, self)
    o:Init()
    return o
end

function CBackendMgr:Init()
    -- 活动推送页签
    self.m_mHuoDongTagInfo = {}
    self.m_mForbinInfo = {}
end

function CBackendMgr:LoadDB()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.sDbKey},
    }
    gamedb.LoadDb("backendinfo", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        self:Load(mData.data)
    end)
end

function CBackendMgr:SaveDb()
    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.sDbKey},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("backendinfo", "common", "DbOperate", mInfo)
end

function CBackendMgr:Load(m)
    if not m then return end

    self.m_mHuoDongTagInfo = m.taginfo or {}
    self.m_mForbinInfo = m.forbininfo or {}
end

function CBackendMgr:Save()
    local mData = {}
    mData.taginfo = self.m_mHuoDongTagInfo
    mData.forbininfo = self.m_mForbinInfo
    return mData
end

function CBackendMgr:FormatHuoDongTagInfo(m)
    local mInfo = {}
    mInfo.hd_type = m.hd_type
    mInfo.show = m.show
    mInfo.min_grade = m.min_grade
    mInfo.index = m.index
    return mInfo
end

function CBackendMgr:UpdateHuoDongTagInf(omData)
    if type(mData) ~= "table" then
        return false, "data formate error"
    end

    local mTagInfo = {}
    for _, m in pairs(mData) do
        local mInfo = self:FormatHuoDongTagInfo(m)
        mTagInfo[mInfo.hd_type] = mInfo
    end
    self.m_mHuoDongTagInfo = mTagInfo
    self:SyncHuoDongTagInfo()
    
    self:SaveDb()
    return true 
end

function CBackendMgr:GetServerList()
    return serverinfo.get_gs_key_list()
end

function CBackendMgr:SyncHuoDongTagInfo()
    local lServerKey = self:GetServerList()
    local mData = self:GetHuoDongTagInfo()
    local sCmd = "SyncHuoDongTagInfo"
    for _, sServerKey in pairs(lServerKey) do
        router.Request(get_server_tag(sServerKey), ".world", "backend", sCmd, mData, function(mRecord, mRes)
            if mRes.errcode and mRes.errcode > 0 then
                record.error("Host:%s SyncHuoDongTagInfo error", sServerKey)
            end
        end)
    end
end

function CBackendMgr:GetHuoDongTagInfo()
    return self.m_mHuoDongTagInfo
end

function CBackendMgr:FormatForbinInfo(mData)
    local iInfo = mData.id
    local sWords = mData.words
    if not iInfo or not sWords or #sWords <= 0 then return end

    return {
        id = iInfo,
        words = sWords,
        status = mData.status,
        punishtype = mData.punishtype,
        punishtime = mData.punishtime,
        limit = mData.limit,
    }
end

function CBackendMgr:UpdateOrSaveForbinInfo(mData)
    local mInfo = self:FormatForbinInfo(mData)
    if not mInfo then return false, "params error" end

    self.m_mForbinInfo[mInfo.id] = mInfo
    self:SaveDb()
    self:SyncForbinInfo(mInfo)
    return true
end

function CBackendMgr:DeleteForbinInfo(ids)
    for _,id in pairs(ids) do
        self.m_mForbinInfo[id] = nil
    end
    self:RemoveForbinInfo(ids)
    self:SaveDb()
end

function CBackendMgr:SyncForbinInfo(mInfo)
    local lServerKey = self:GetServerList()
    local sCmd = "SyncForbinInfo"
    for _, sServerKey in pairs(lServerKey) do
        router.Send(get_server_tag(sServerKey), ".chat", "common", sCmd, {data=mInfo}, function(mRecord, mRes)
            if mRes.errcode and mRes.errcode > 0 then
                record.error("Host:%s SyncForbinInfo error", sServerKey)
            end
        end)
    end
end

function CBackendMgr:RemoveForbinInfo(ids)
    local lServerKey = self:GetServerList()
    local sCmd = "RemoveForbinInfo"
    for _, sServerKey in pairs(lServerKey) do
        router.Send(get_server_tag(sServerKey), ".chat", "common", sCmd, {ids=ids}, function(mRecord, mRes)
            if mRes.errcode and mRes.errcode > 0 then
                record.error("Host:%s RemoveForbinInfo error", sServerKey)
            end
        end)
    end
end

function CBackendMgr:GetForbinInfo()
    return self.m_mForbinInfo
end




