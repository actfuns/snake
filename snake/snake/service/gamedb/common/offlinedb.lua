--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sOfflineTableName = "offline"

function CreateOffline(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sOfflineTableName, mData.data)
end

function LoadOfflineProfile(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {profile_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.profile_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineProfile(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={profile_info = mData.data}},true)
end

function LoadOfflineFriend(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {friend_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.friend_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineFriend(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={friend_info = mData.data}},true)
end

function LoadOfflineMailBox(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {mail_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.mail_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineMailBox(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={mail_info = mData.data}},true)
end

function LoadOfflineJJC(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {jjc_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.jjc_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineJJC(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={jjc_info = mData.data}},true)
end

function LoadOfflineChallenge(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {challenge_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.challenge_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineChallenge(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={challenge_info = mData.data}},true)
end

function LoadOfflineWanfaCtrl(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {wanfa_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.wanfa_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineWanfaCtrl(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={wanfa_info = mData.data}},true)
end

function LoadOfflinePrivacy(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {privacy_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.privacy_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflinePrivacy(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={privacy_info = mData.data}},true)
end

function LoadOfflineFeedBack(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sOfflineTableName, {pid = mCond.pid}, {feedback_info = true})

    local mRet
    if m then
        mRet = {
            success = true,
            data = m.feedback_info,
            pid = mCond.pid,
        }
    else
        mRet = {
            success = false,
        }
    end
    return mRet
end

function SaveOfflineFeedBack(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sOfflineTableName, {pid = mCond.pid}, {["$set"]={feedback_info = mData.data}}, true)
end
