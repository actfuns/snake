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

function NewBackendInfoMgr(...)
    local o = CBackendInfoMgr:New(...)
    return o
end

CBackendInfoMgr = {}
CBackendInfoMgr.__index = CBackendInfoMgr

function CBackendInfoMgr:New()
    local o = setmetatable({}, self)
    o:Init()
    return o
end

function CBackendInfoMgr:Init()
end

function CBackendInfoMgr:LoadDB()
end

function CBackendInfoMgr:GetServerById(sServer)
    return serverinfo.get_gs_info(sServerKey)
end

function CBackendInfoMgr:GetResourceInfo(sType)
    if sType == "hdcontrol" then
        return self:GetHDControlResource()
    end
    return self:GetBaseResourceInfo(sType)
end

function CBackendInfoMgr:GetBaseResourceInfo(sType)
    local mTable = {
        item = {{"daobiao", "item"}, {"id", "name"}},
        task = {{"daobiao", "task", "story", "task"}, {"id", "name"}},
        store = {{"daobiao", "npcstore", "data"}, {"id", "item_id"}},
        summon = {{"daobiao", "summon", "info"}, {"id", "name"}},
        pay = {{"daobiao", "pay"}, {"key", "name"}},
        ride = {{"daobiao", "ride", "rideinfo"}, {"id", "name"}},
    }

    local mResource = mTable[sType]
    if not mResource then
        record.warning("gmtools get daobiao res error type: %s", sType)
        return {} 
    end

    local mRet = {}
    local mUrl, mKey = mResource[1], mResource[2]
    local mData = table_get_depth(res, mUrl) 
    for _, mInfo in pairs(mData) do
        if sType == "store" then
            local mData = res["daobiao"]["item"][mInfo[mKey[2]]]
            local sName = mInfo[mKey[1]]
            if mData then sName = mData["name"] end

            table.insert(mRet, {id = mInfo[mKey[1]], name = sName})    
        else
            table.insert(mRet, {id = mInfo[mKey[1]], name = mInfo[mKey[2]]})
        end
    end
    return mRet
end

function CBackendInfoMgr:GetHDControlResource()
    local mData = res["daobiao"]["hdcontrol"]
    local mRet = {}
    for _, m in pairs(mData) do
        table.insert(mRet, m)
    end
    return mRet
end


