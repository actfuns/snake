--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sOrgTableName = "orgready"

function CreateReadyOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sOrgTableName, mData.data)
end

function RemoveReadyOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Delete(sOrgTableName, {orgid = mCond.orgid})
end

function GetAllReadyOrgID(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sOrgTableName, {}, {orgid = true})
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    return {data = mRet}
end

function LoadReadyOrg(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {name = true, data = true})
    return {
        data = m,
        orgid = mCond.orgid,
    }
end

function SaveReadyOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={name = mData.name, data = mData.data}})
end
