--import module
local global = require "global"
local skynet = require "skynet"
local router = require "base.router"

------------------ks 2 gs-----------------------------------
function KS2GSProfileRemoteEvent(mRecord, mData)
    local func = function (mRet)
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
            errcode = 0, 
            data = mRet
        })
    end
    local iPid = mData.pid
    global.oWorldMgr:LoadProfile(iPid, function (oProfile)
        if oProfile then
            oProfile:RemoteKsEvent(mData, func)            
        end
    end)
end

function KS2GSRemoteEvent(mRecord, mData)
    local sEvent = mData.event
    local mArgs = mData.args
    global.oKuaFuMgr:RemoteEvent(sEvent, mRecord.srcsk, mArgs)    
end

function KS2GSLoadOffline(mRecord, mData)
    local sKey = mData.key
    local iPid = mData.pid
    global.oKuaFuMgr:RemoteLoadOffline(sKey, iPid, function (mOffline)
        local bSucc = mOffline and true or false
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {
            data = mOffline,
            success = bSucc,
            pid = iPid,
        })
    end)
end

function KS2GSAddMail(mRecord, mData)
   local iPid = mData.pid
   local mMail = mData.mail
   global.oMailMgr:AddKSMail(iPid, mMail) 
end

function KS2GSSaveAll(mRecord, mData)
    local mRet = global.oKuaFuMgr:SavePlayerAllInfo(mData)
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRet)
end

function KS2GSSaveModule(mRecord, mData)
    global.oKuaFuMgr:SavePlayerModuleInfo(mData)
end

function KS2GSPushData2Rank(mRecord, mData)
    local iPid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    --玩家在原服， 使用原服数据
    if oPlayer then return end

    interactive.Send(".rank", "rank", "PushDataToRank", mInfo)
end

function KS2GSPushDataToEveryDayRank(mRecord, mData)
    local iPid = mData.pid
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then return end

    global.oRankMgr:KS2GSPushDataToEveryDayRank(mData)
end

function KS2GSAddTaskCnt(mRecord, mData)
    global.oMentoring:AddTaskCntByKSData(mData)
end

function KS2GSAddStepResultCnt(mRecord, mData)
    global.oMentoring:AddStepResultCntByKSData(mData)
end
