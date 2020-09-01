local skynet = require "skynet"
local interactive = require "base.interactive"
local global  =require "global"
local sTableName = "bulletbarrage"

function LoadBulletBarrage(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sTableName, {id = mCond.id, type=mCond.type}, {data = true})
    local mRet = {}
    if not m then
        mRet.success = false
    else
        mRet = {
            id = m.id,
            type = m.type,
            data = m.data,
            success = true,
        }
    end
    return mRet
end

function SaveBulletBarrage(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sTableName, {id = mCond.id,type = mCond.type}, {["$set"]={data = mData.data}}, true)
end