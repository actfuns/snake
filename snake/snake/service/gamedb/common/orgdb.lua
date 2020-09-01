--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sOrgTableName = "org"

function CreateOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sOrgTableName, mData.data)
end

function RemoveOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Delete(sOrgTableName, {orgid = mCond.orgid})
end

function GetAllOrgID(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sOrgTableName, {}, {orgid = true})
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    return {
        data = mRet,
    }
end

function LoadWholeOrg(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, 
        {orgid = true, name = true, showid = true, base_info = true, member_info = true, 
        build_info = true, log_info = true, apply_info = true, boon_info = true, achieve_info = true})
    return {
        data = m,
        orgid = mCond.orgid,
    }
end

function SaveOrg(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"] = mData.data})
end

function LoadOrg(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {name = true})
    return {
        data = m,
        orgid = mCond.orgid,
    }
end

function SaveOrgBase(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={base_info = mData.data}})
end

function LoadOrgBase(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {base_info = true})
    return {
        data = m.base_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgMember(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={member_info = mData.data}})
end

function LoadOrgMember(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {member_info = true})
    return {
        data = m.member_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgBuild(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={build_info = mData.data}})
end

function LoadOrgBuild(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {build_info = true})
    return {
        data = m.build_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgLog(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={log_info = mData.data}})
end

function LoadOrgLog(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {log_info = true})
    return {
        data = m.log_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgApply(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={apply_info = mData.data}})
end

function LoadOrgApply(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {apply_info = true})
    return {
        data = m.apply_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgBoon(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={boon_info = mData.data}})
end

function LoadOrgBoon(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {boon_info = true})
    return {
        data = m.boon_info,
        orgid = mCond.orgid,
    }
end

function SaveOrgAchieve(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOrgTableName, {orgid = mCond.orgid}, {["$set"]={achieve_info = mData.data}})
end

function LoadOrgAchieve(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOrgTableName, {orgid = mCond.orgid}, {achieve_info = true})
    return {
        data = m.achieve_info,
        orgid = mCond.orgid,
    }
end

function GetConflictNameOrg(mCond,mData)
    local oGameDb = global.oGameDb
    local m1 = oGameDb:Find(sOrgTableName, {}, {orgid = true, name = true, from_server = true})
    local m2 = oGameDb:Find("orgready", {}, {orgid = true, name = true, from_server = true})
    local mOrgs = {}
    local mRet = {}
    while (m1:hasNext() or m2:hasNext()) do
        local mInfo
        if m1:hasNext() then
            mInfo = m1:next()
        else
            mInfo = m2:next()
        end
        local sName = mInfo.name
        local mNameInfo = mOrgs[sName]
        if not mNameInfo then
            mOrgs[sName] = mInfo
        else
            if mNameInfo.from_server and mNameInfo.from_server ~= get_server_tag() then
                mOrgs[sName] = mInfo
                mRet[mNameInfo.orgid] = sName
            elseif mInfo.from_server and mInfo.from_server ~= get_server_tag() then
                mRet[mInfo.orgid] = sName
            end
        end
    end
    return mRet
end