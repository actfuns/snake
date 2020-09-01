local M = {}
local sModelName = ...
_G[sModelName] = M
package.loaded[sModelName] = M
setmetatable(M, {__index = _G})

-- loadfile_ex = function (sFileName, sMode, mEnv)
--     sMode = sMode or "bt"
--     mEnv = mEnv or _ENV
--     local h = io.open(sFileName, "rb")
--     assert(h, string.format("loadfile_ex fail %s", sFileName))
--     local sData = h:read("*a")
--     h:close()
--     local f, s = load(sData, sFileName, sMode, mEnv)
--     assert(f, string.format("loadfile_ex fail %s", s))
--     return f
-- end
-- function import(sModule)
--     local sPath =  sModule .. ".lua"
--     local m = setmetatable({}, {__index = _G})
--     local f, s = loadfile_ex(sPath, "bt", m)
--     f()
--     return m
-- end

-- local tableop = import("lualib/base/tableop")

function table_combine(mDest, mSrc)
    for k, v in pairs(mSrc) do
        mDest[k] = v
    end
end

function table_deep_combine(mDest, mSrc)
    for k, v in pairs(mSrc) do
        if type(v) == "table" then
            local mDestK = touch_mapping(mDest, {k})
            table_deep_combine(mDestK, v)
        else
            mDest[k] = v
        end
    end
end

function simple_table(mT)
    local mRet = {}
    for k, v in pairs(mT) do
        if type(v) == "number" and v == 0 then
            goto continue
        end
        if(type(v) == "table" and not next(v)) then
            goto continue
        end
        mRet[k] = v
        ::continue::
    end
    return mRet
end

function touch_mapping(mRoot, lPath)
    local v = mRoot
    for _, k in ipairs(lPath) do
        if type(k) ~= "number" and type(k) ~= "string" then
            return nil
        end
        if type(v) ~= "table" then
            return nil
        end
        if not v[k] then
            v[k] = {}
        end
        v = v[k]
    end
    return v
end

function parse_list(mList)
    local mParsed = {}
    for iKey, xValue in pairs(mList) do
        mParsed[tostring(iKey)] = xValue
    end
    return mParsed
end

function release(obj)
    local mKeys = {}
    for k, v in pairs(obj) do
        mKeys[k] = 1
    end
    for k, _ in pairs(mKeys) do
        obj[k] = nil
    end
end

--------------------------------
CGroupWalker = {}
CGroupWalker.__index = CGroupWalker
function CGroupWalker:New()
    local o = setmetatable({}, self)
    o.m_mGroupUp = {}
    o.m_mRingNode = {}
    return o
end

function CGroupWalker:GatherAEvGroup(sEventId, mEventGroups)
    local mEvGroup = mEventGroups[sEventId]
    if not mEvGroup or not next(mEvGroup) then
        return {}, false
    end
    local mGroupUp = self.m_mGroupUp[sEventId]
    if mGroupUp then
        return mGroupUp, true
    end
    mGroupUp = {}
    self.m_mGroupUp[sEventId] = mGroupUp

    -- 先序遍历，先记录当前点
    mGroupUp[sEventId] = 1

    for sNextEv, _ in pairs(mEvGroup) do
        mGroupUp[sNextEv] = 1
        -- 递归子节点
        local mChildren, bRing = self:GatherAEvGroup(sNextEv, mEventGroups)
        if bRing then
            -- TODO 处理环
            -- local mNexts = self.m_mRingNode[]
        end
        table_combine(mGroupUp, mChildren)
    end
    return mGroupUp
end
--------------------------------

CTaskTopology = {}
CTaskTopology.__index = CTaskTopology
function CTaskTopology:New()
    local o = setmetatable({}, self)
    o.m_mAllTasks = {}
    o.m_mAllEvents = {}
    o.m_mDeepEvGroups = {}
    return o
end

local M_CMD_KEYS = {
    look = 1,
    answer = 1,
    win = 1,
    fail = 1,
    reach = 1,
}

function CTaskTopology:PickEventId(sCmd)
    local sEventId = string.match(sCmd, "^E%d+:(%d+)$")
    if sEventId then
        return sEventId
    end
    local sEventId = string.match(sCmd, "^EC(%d+)$")
    if sEventId then
        return sEventId
    end
end

function CTaskTopology:FindOutEventIds(lCmds)
    local mEvIds = {}
    for _, sCmd in ipairs(lCmds) do
        local sEventId = self:PickEventId(sCmd)
        if sEventId then
            mEvIds[sEventId] = 1
        end
    end
    return mEvIds
end

function CTaskTopology:SearchEvent(mTaskInfo)
    local lCmds = mTaskInfo.initConfig
    local mEventIds = self:FindOutEventIds(lCmds)
    local mRetEvs = {}
    for sEvId, _ in pairs(mEventIds) do
        local mEvGroup = self.m_mDeepEvGroups[sEvId]
        if mEvGroup then
            table_combine(mRetEvs, mEvGroup)
        end
    end
    table_combine(mRetEvs, mEventIds)
    return mRetEvs
end

function CTaskTopology:ShallowBuildEvents(mAllEvents)
    local mEventGroups = {}
    for iEventId, mEvent in pairs(mAllEvents) do
        local sEventId = tostring(iEventId)
        local mEvent = mAllEvents[iEventId]
        assert(mEvent, string.format("event [%s] not defined", sEventId))
        local mGroupEvs = {}
        for sKey, _ in pairs(M_CMD_KEYS) do
            local lCmds = mEvent[sKey]
            local mEvIds = self:FindOutEventIds(lCmds)
            table_combine(mGroupEvs, mEvIds)
        end
        mEventGroups[sEventId] = mGroupEvs
    end
    return mEventGroups
end

function CTaskTopology:GetNextTaskInCmd(lCmds)
    local mNexts = {}
    for _, sCmd in ipairs(lCmds) do
        local sTaskId = string.match(sCmd, "^NT(%d+)$")
        if sTaskId then
            mNexts[sTaskId] = 1
        end
    end
    return mNexts
end

function CTaskTopology:GetNextFuncDefault(mTaskInfo)
    local lCmds = mTaskInfo.missiondone
    local mNexts = {}
    table_combine(mNexts, self:GetNextTaskInCmd(lCmds))
    local mEvents = self:SearchEvent(mTaskInfo)
    for sEvId, _ in pairs(mEvents) do
        local mEvData = self.m_mAllEvents[sEvId]
        for sKey, _ in pairs(M_CMD_KEYS) do
            local lCmds = mEvData[sKey]
            table_combine(mNexts, self:GetNextTaskInCmd(lCmds))
        end
    end
    if next(mNexts) then
        local lIds = {}
        for k,v in pairs(mNexts) do
            table.insert(lIds, k)
        end
        return mNexts
    else
        return nil
    end
end

local M_FUNC_NEXT_GETTER = { }
function CTaskTopology:GetTaskNext(mTaskInfo)
    local sFuncGetter = M_FUNC_NEXT_GETTER[self.m_sTaskGroup] or "GetNextFuncDefault"
    local fGetter = self[sFuncGetter]
    return fGetter(self, mTaskInfo)
end

function CTaskTopology:SetNext(mTree, sTaskId, mNexts)
    local mData = touch_mapping(mTree, {sTaskId})
    local mNextData = touch_mapping(mData, {"next"})
    for sNext, _ in pairs(mNexts) do
        mNextData[sNext] = 1
    end
    return mTree
end

function CTaskTopology:SetPrev(mTree, sTaskId, mNexts)
    for sNext, _ in pairs(mNexts) do
        local mData = touch_mapping(mTree, {sNext})
        local mPrevData = touch_mapping(mData, {"prev"})
        mPrevData[sTaskId] = 1
    end
    return mTree
end

function CTaskTopology:SwitchHead(mHeads, sTaskId, mNexts)
    if not mHeads[sTaskId] then
        mHeads[sTaskId] = 1
    end
    for sNext, _ in pairs(mNexts) do
        mHeads[sNext] = 0
    end
end

function CTaskTopology:SwitchTail(mTails, sTaskId, mNexts)
    mTails[sTaskId] = 0
    for sNext, _ in pairs(mNexts) do
        if not mTails[sNext] then
            mTails[sNext] = 1
        end
    end
end


-- {heads:头, tails:尾, links:{sTaskid:{prev:{taskid:1,...},next:{taskid:1,...}}}}
function CTaskTopology:WalkRivers()
    local mWalked = {}
    local mTree = {}
    local mTails = {}
    local mHeads = {}
    for sTaskId, mInfo in pairs(self.m_mAllTasks) do
        mWalked[sTaskId] = 1
        local mNexts = self:GetTaskNext(mInfo)
        if mNexts then
            self:SetNext(mTree, sTaskId, mNexts)
            self:SetPrev(mTree, sTaskId, mNexts)
            self:SwitchTail(mTails, sTaskId, mNexts)
            self:SwitchHead(mHeads, sTaskId, mNexts)
        end
    end
    return {
        links = mTree,
        tails = simple_table(mTails),
        heads = simple_table(mHeads),
    }
end

function CTaskTopology:DeepGroupEvents(mEventGroups)
    local mDeepGroups = {}
    for sEventId, mEvGroup in pairs(mEventGroups) do
        if next(mEvGroup) then
            local oGrouper = CGroupWalker:New()
            oGrouper:GatherAEvGroup(sEventId, mEventGroups)
            table_combine(mDeepGroups, oGrouper.m_mGroupUp)
            release(oGrouper)
        end
    end
    return mDeepGroups
end

function CTaskTopology:GetTaskPieces(sTaskId, mTaskLinks)
    local mLinkInfo = mTaskLinks[sTaskId]
    if not mLinkInfo then
        assert(nil, sTaskId)
    end
    local mChPieces = {}
    local mPrevTasks = mLinkInfo.prev
    if not mPrevTasks then
        return mChPieces
    end
    for sPrevTaskId, _ in pairs(mPrevTasks) do
        local mTaskInfo = self.m_mAllTasks[sPrevTaskId]
        local lCmds = mTaskInfo.missiondone
        for _, sCmd in ipairs(lCmds) do
            local sChapter, sPieceId = string.match(sCmd, "^CHP(%d+):(%d+)$")
            if sChapter and sPieceId then
                local mChapter = touch_mapping(mChPieces, {sChapter})
                mChapter[sPieceId] = 1
            end
        end
    end
    return mChPieces
end

function CTaskTopology:StepPieces(mTaskLinks, mAllPieces, sTaskId)
    local mChPieces = self:GetTaskPieces(sTaskId, mTaskLinks)
    mAllPieces[sTaskId] = mChPieces
    local mLinkInfo = mTaskLinks[sTaskId]
    if not mLinkInfo then
        assert(nil, sTaskId)
    end
    if not mLinkInfo.prev then
        return mChPieces
    end
    for sPrevId, _ in pairs(mLinkInfo.prev) do
        table_deep_combine(mChPieces, self:StepPieces(mTaskLinks, mAllPieces, sPrevId))
    end
    return mChPieces
end

function CTaskTopology:WalkOutPieces(mTaskRiver)
    local mAllPieces = {}
    for sTailId, _ in pairs(mTaskRiver.tails) do
        self:StepPieces(mTaskRiver.links, mAllPieces, sTailId)
    end
    return mAllPieces
end

-- 主线章节碎片集合{sTaskid:{sChapter:lPieceLeist}}
function CTaskTopology:WalkOutPiecesList(mTaskRiver)
    local mAllPieces = self:WalkOutPieces(mTaskRiver)
    for sTaskId, mChPieces in pairs(mAllPieces) do
        for sChapter, mPieceInfo in pairs(mChPieces) do
            -- local iCnt = 0
            local lPieces = {}
            for sPieceId, _ in pairs(mPieceInfo) do
                -- iCnt = iCnt + 1
                table.insert(lPieces, sPieceId)
            end
            mChPieces[sChapter] = lPieces
        end
    end
    return simple_table(mAllPieces)
end

function CTaskTopology:Init(sGamedataPath, sTaskGroup)
    print("gamedata 路径:", sGamedataPath)
    local gamedata
    local res, err = pcall(function() gamedata = require(sGamedataPath) end)
    if not gamedata then
        print("gamedata路径无法找到文件")
        print(err)
        return false
    end
    self.m_sTaskGroup = sTaskGroup
    self.m_mAllTasks = parse_list(gamedata.task[sTaskGroup].task)
    self.m_mAllEvents = parse_list(gamedata.task[sTaskGroup].taskevent)
    local mEventGroups = self:ShallowBuildEvents(self.m_mAllEvents) -- 事件及其显示调用的事件聚合{sEvId:<同组ev>{sEvId:1}}
    self.m_mDeepEvGroups = self:DeepGroupEvents(mEventGroups) -- 浅聚合的mEventGroups基础上深度遍历图聚合
    return true
end

-- TODO 任务链、事件组，都需要使用有向图环检测
function CTaskTopology:TaskTopology()
    local iTaskCnt = 0
    for sId,_ in pairs(self.m_mAllTasks) do
        iTaskCnt = iTaskCnt + 1
    end
    print("AllTaskCnt:", iTaskCnt)

    local mTaskRiver = self:WalkRivers()
    return mTaskRiver
end

function NewTaskTopology(...)
    return CTaskTopology:New(...)
end

return M
