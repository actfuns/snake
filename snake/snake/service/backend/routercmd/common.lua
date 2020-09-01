--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"
local extend = require "base.extend"

function SaveBackendLog(mRecord, mData)
    local oBackendObj = global.oBackendObj
    local oBackendDb = oBackendObj.m_oBackendDb

    mData = extend.Table.deserialize(mData)
    local iPid = mData["pid"]
    local sType = mData["type"]
    local tBackend = oBackendDb:GetDB()
    local mQuery = {["pid"] = iPid, ["type"] = sType}
    local mDocument = {["pid"] = iPid, ["type"] = sType, ["data"] = mData["data"]}
    local mCondition = {upsert = true}
    oBackendDb:Update(mData.tablename, mQuery, mDocument, mCondition)
end

function RegisterGS2BS(mRecord, mData)
    local oBackendObj = global.oBackendObj
    local sServerKey = mData["serverkey"]
    oBackendObj:RegisterGS(sServerKey)
end

function GetHuoDongTagInfo(mRecord, mData)
    local oBackendInfoMgr = global.oBackendInfoMgr
    local mInfo = oBackendInfoMgr:GetHuoDongTagInfo()
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
        errcode = 0,
        data = mInfo,
    })
end

