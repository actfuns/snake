--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"

local dbcommon = import(service_path("common.init"))

function FindDb(mRecord, mData)
    local oGameDb = global.oGameDb
    local sTableName = mData.table
    local mSearch = mData.search
    local mBackInfo = mData.back
    local m = oGameDb:Find(sTableName, mSearch, mBackInfo)
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    mongoop.ChangeAfterLoad(mRet)
    interactive.Response(mRecord.source, mRecord.session, {
        data = mRet,
    })
end

function DbOperate(mRecord, mData)
    local sModule = mData.module
    local sCmd = mData.cmd
    local mCond = mData.cond
    local mSave = mData.data
    if mSave then
        mongoop.ChangeBeforeSave(mSave)
    end
    local ret = dbcommon.Invoke(sModule, sCmd, mCond, mSave)
    if ret then
        mongoop.ChangeAfterLoad(ret)
        interactive.Response(mRecord.source, mRecord.session, ret)
    end
end
