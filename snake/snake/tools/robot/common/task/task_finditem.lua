--寻物任务
local taskobj = require("common/task/taskobj")

local CTaskObj = {m_iTaskType = 0}
CTaskObj.__index = CTaskObj
setmetatable(CTaskObj,taskobj)

function CTaskObj:New(iTaskType)
    local o = setmetatable({}, CTaskObj)
    o.m_iTaskType = iTaskType
    return o
end

function CTaskObj:GS2CNpcSay(oPlayer,mCurTaskInfo,mArgs)
    local iSessionIdx = mArgs.sessionidx
    oPlayer:sleep(1)
    oPlayer:run_cmd("C2GSTaskEvent",{npcid = mArgs.npcid,taskid = mCurTaskInfo.taskid})
end

function CTaskObj:GS2CAutoFindPath(oPlayer,mTaskInfoTbl,mArgs)
    local iNpcId = mArgs.npcid
    oPlayer:run_cmd("C2GSClickNpc",{npcid = iNpcId})
end

function CTaskObj:GS2CSendCatalog(oPlayer, mTask, mArgs)
    local iCatId = mArgs.cat_id
    local lCatalog = mArgs.catalog
    local iAmount, iSid, iPos
    for idx, mItem in ipairs(mArgs.catalog or {}) do
        if mItem.sid == mTask.needitem.itemid then
            iSid = mItem.sid
            iAmount = mTask.needitem.amount
            iPos = idx
            oPlayer:run_cmd("C2GSRunCmd", {cmd="addsilver "..(mItem.price*iAmount)})
            break
        end
    end
    if iAmount and iSid and iPos then
        oPlayer:run_cmd("C2GSBuySellItem", {amount=iAmount, cat_id=iCatId, pos_id=iPos})
        oPlayer:run_cmd("C2GSClickTask", {taskid=mTask.taskid})
    end
end

function CTaskObj:GS2CPopTaskItem(oPlayer, mTask, mArgs)
    local iSession = mArgs.sessionidx
    local iTask = mArgs.taskid
    if iTask ~= mTask.taskid then
        return
    end
    local mItem = mTask.needitem
    local iSid = mItem.itemid
    local iNeed = mItem.amount
    local lItemList = oPlayer:GetItemListBySid(iSid)
    if not next(lItemList) then
        return
    end

    local lResult = {}
    for _, lInfo in ipairs(lItemList) do
        local iPos, iItem, iTotal = table.unpack(lInfo)
        if iNeed > iTotal then
            table.insert(lResult, {amount=iTotal, id=iItem})
            iNeed = iNeed - iTotal
        else
            table.insert(lResult, {amount=iNeed, id = iItem})
            iNeed = 0
        end
        if iNeed <= 0 then
            break
        end
    end
    oPlayer:run_cmd("C2GSCallback", {sessionidx=iSession, itemlist=lResult})
end

return CTaskObj
