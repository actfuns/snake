--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sKuaFuTable = "kuafuinfo"
function GetKuaFuByPid(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sKuaFuTable, {pid = mCond.pid}, {pid = true, info = true})
    return {
        data = m,
        pid = mCond.pid,
    }
end

function LoadAllKuaFuInfo(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sKuaFuTable, {}, {pid = true, info = true})
    local lResult = {}
    while m:hasNext() do
        local mInfo = m:next()
        mInfo["_id"] = nil
        table.insert(lResult, mInfo)
    end
    return {
        data = lResult,
    }
end

function CreateKuaFu(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sKuaFuTable, mData.data)
end

function RemoveKuaFu(mCond, mData)
    local oGameDb = global.oGameDb
    local ok, err = oGameDb:Delete(sKuaFuTable, {pid = mCond.pid})
    return {ok = ok, err = err}
end

function UpdateKuaFu(mCond, mData)
    local oGameDb = global.oGameDb
    local ok, err = oGameDb:Update(sKuaFuTable, {pid = mCond.pid}, {["$set"]={info=mData.data}}, true)
    return {ok = ok, err = err}
end
