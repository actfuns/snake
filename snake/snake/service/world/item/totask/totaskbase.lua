local global = require "global"

local itembase = import(service_path("item/itembase"))
local taskdefines = import(service_path("task/taskdefines"))

CItem = {}
CItem.__index = CItem
inherit(CItem, itembase.CItem)
CItem.m_ItemType = "totask"

function NewItem(sid)
    local o = CItem:New(sid)
    return o
end


function CItem:ToTaskId()
    local iTaskId = self:GetItemData()["taskid"]
    if iTaskId and iTaskId <= 0 then
        return nil
    end
    return iTaskId
end

function CItem:TrueUse(oPlayer, target)
    local iTaskId = self:ToTaskId()
    local oTask = global.oTaskLoader:CreateTask(iTaskId)
    assert(oTask, string.format("item toTask err, item:%d, taskid:%s", self:SID(), iTaskId))
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sMsg
    local bSucc,iErr = oPlayer.m_oTaskCtrl:CanAddTask(oTask)
    if bSucc then
        local sTaskName = oTask:Name()
        sMsg = oToolMgr:FormatColorString("你获得了任务#task", {task = sTaskName})
    else
        sMsg = taskdefines.GetErrMsg(iErr)
        oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
        return
    end

    local iCostAmount = self:GetUseCostAmount()
    -- self:GS2CConsumeMsg(oPlayer)
    oPlayer:RemoveOneItemAmount(self,iCostAmount,"itemuse")

    oPlayer.m_oTaskCtrl:AddTask(oTask, nil, true)
    oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    return true
end

function CItem:CanUseOnKS()
    return false
end
