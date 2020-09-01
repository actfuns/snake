--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function Register(mRecord, mData)
    local oUpdateMgr = global.oUpdateMgr
    local iPid = mData.pid
    local mInfo = mData.info
    oUpdateMgr:Add(iPid, mInfo)
    oUpdateMgr:OnRegister(iPid)
end

function UnRegister(mRecord, mData)
    local oUpdateMgr = global.oUpdateMgr
    local iPid = mData.pid
    oUpdateMgr:Del(iPid)
    oUpdateMgr:OnUnRegister(iPid)
end

function CodeUpdate(mRecord, mData)
    local oUpdateMgr = global.oUpdateMgr
    oUpdateMgr:OnCodeUpdate()
end

function ResUpdate(mRecord, mData)
    local oUpdateMgr = global.oUpdateMgr
    oUpdateMgr:OnResUpdate()
end

function QueryResUpdate(mRecord, mData)
    local oUpdateMgr = global.oUpdateMgr
    local iPid = mData.pid
    local mClientData = mData.data
    local mVersion = mClientData.res_file_version or {}
    oUpdateMgr:OnQueryResUpdate(iPid, mVersion)
end

function QueryLogin(mRecord,mData)
    local oUpdateMgr = global.oUpdateMgr
    local mFileVersion = mData.res_file_version or {}
    local mResData = oUpdateMgr:QueryLogin(mFileVersion)
    interactive.Response(mRecord.source, mRecord.session, {
        res_file = mResData
    })
end

