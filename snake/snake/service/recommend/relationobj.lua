--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local net = require "base.net"

function NewRelationObj(...)
    local o = CRelationObj:New(...)
    return o
end

CRelationObj = {}
CRelationObj.__index = CRelationObj
inherit(CRelationObj, logic_base_cls())

function CRelationObj:New()
    local o = super(CRelationObj).New(self)
    o.m_mRelation = {}
    return o
end

function CRelationObj:UpdateOneDegreeFriends(iPid, mData)
    self.m_mRelation[iPid] = mData
end

function CRelationObj:ClearAllCache()
    self.m_mRelation = {}
end

function CRelationObj:DigTwoDegreeFriends(iPid, mRecordBack)
    local m = self.m_mRelation[iPid]
    if m then
        self:_ExecuteOneDegree(mRecordBack, iPid, m)
    else
        interactive.Request(".world", "friend", "RecommendFindFriend", {pid = iPid}, function (mRecord, mData)
            if not is_release(self) then
                if not mData.data then
                    interactive.Response(mRecordBack.source, mRecordBack.session, {
                        success = false
                    })
                else
                    self:_ExecuteOneDegree(mRecordBack, iPid, mData.data)
                end
            end
        end)
    end
end

function CRelationObj:_ExecuteOneDegree(mRecordBack, iPid, mOneDegreeFriend)
    local iRequestCount = table_count(mOneDegreeFriend)
    self:UpdateOneDegreeFriends(iPid, mOneDegreeFriend)
    if iRequestCount <= 0 then
        interactive.Response(mRecordBack.source, mRecordBack.session, {
            success = true,
            data = {},
        })
    else
        local mHandle = {
            count = iRequestCount,
            map = {},
            is_sent = false,
        }
        for k, v in pairs(mOneDegreeFriend) do
            local m = self.m_mRelation[k]
            if m then
                self:_ExecuteTwoDegree(mRecordBack, mHandle, iPid, k, mOneDegreeFriend, m)
            else
                    interactive.Request(".world", "friend", "RecommendFindFriend", {pid = k}, function (mRecord, mData)
                        if not is_release(self) then
                            if not mData.data then
                                mHandle.count = mHandle.count - 1
                                self:JudgeRecordBack(mRecordBack, mHandle)
                            else
                                self:_ExecuteTwoDegree(mRecordBack, mHandle, iPid, k, mOneDegreeFriend, mData.data)
                            end
                        end
                    end)
            end
        end
    end
end

function CRelationObj:_ExecuteTwoDegree(mRecordBack, mHandle, iSourcePid, iPid, mOne, mTwo)
    mHandle.count = mHandle.count - 1
    for k, v in pairs(mTwo) do
        if not mOne[k] then
            mHandle.map[k] = 1
        end
    end
    mHandle.map[iSourcePid] = nil
    self:UpdateOneDegreeFriends(iPid, mTwo)
    self:JudgeRecordBack(mRecordBack, mHandle)
end

function CRelationObj:JudgeRecordBack(mRecordBack, mHandle)
    if mHandle.count <= 0 and not mHandle.is_sent then
        interactive.Response(mRecordBack.source, mRecordBack.session, {
            success = true,
            data = mHandle.map,
        })
        mHandle.is_sent = true
    end
end
