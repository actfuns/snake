--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sTableName = "warvideo"

function LoadWarVideo(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sTableName, {video_id = mCond.video_id}, {video_info = true})
    local mRet = {}
    if m then
        mRet = {
            success = true,
            data = m.video_info,
            video_id = m.video_id,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveWarVideo(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sTableName, {video_id = mCond.video_id}, {["$set"]={video_info = mData.data}},true)
end
