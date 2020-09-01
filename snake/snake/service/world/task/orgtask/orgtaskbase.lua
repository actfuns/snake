local global = require "global"
local res = require "base.res"
local record = require "public.record"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))


function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "orgtask"
CTask.m_sTempName = "帮派任务"
inherit(CTask, taskobj.CTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:Name()
    -- local sRing = self:TransStringFuncRing() .. "环"
    return super(CTask).Name(self) .. self:TransCountingStr()
end

function CTask:TransCountingStr()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    assert(oPlayer, "shimen task offline to get doneRing")
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})

    local iRing = mOrgTaskInfo.ring or 0
    if mOrgTaskInfo.curtask then
        iRing  = iRing +1
    end
    if iRing == 0 then
        iRing = 1
    end
    return string.format("(%d/7)", iRing)
end

function CTask:AfterMissionDone(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid) 
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgtask")
    oHuodong:TaskEnd(oPlayer,self)
end

function CTask:GetRewardEnv(oAwardee)
    local pid = self.m_Owner
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})

    local iRing = mOrgTaskInfo.ring or 0
    if mOrgTaskInfo.curtask then
        iRing  = iRing +1
    end
    if iRing == 0 then
        iRing = 1
    end

    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local stu = 1
    local orgobj = oPlayer:GetOrg()
    if orgobj and orgobj:IsXueTu(pid) then
        stu = 2
    end

    return {
        lv = oAwardee:GetGrade(),
        SLV = iServerGrade,
        ring = iRing,
        stu = stu,
    }
end

function CTask:Click(pid)
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if not oPlayer:GetOrg() then
        local sText = oToolMgr:GetTextData(1006,{"huodong", "orgtask"})
        oNotifyMgr:Notify(pid,sText)
        return
    end
    super(CTask).Click(self, pid)
end


function CTask:BuildClientNpcArgs(iNpcType, pid, bPos)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
        local mPreTaskInfo = mOrgTaskInfo.pretaskinfo
        if mPreTaskInfo and mPreTaskInfo.npctype and mPreTaskInfo.npctype~=iNpcType then
            iNpcType = mPreTaskInfo.npctype
        end
    end
    local mArgs = super(CTask).BuildClientNpcArgs(self, iNpcType, pid, bPos)

    if oPlayer then
        local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
        local mPreTaskInfo = mOrgTaskInfo.pretaskinfo
        if mPreTaskInfo then
            if mPreTaskInfo.npcname and mArgs.name ~= mPreTaskInfo.npcname then
                mArgs.name = mPreTaskInfo.npcname

            end
            if mPreTaskInfo.mapid and mArgs.map_id ~= mPreTaskInfo.mapid then
                mArgs.map_id = mPreTaskInfo.mapid
                local x,y
                x, y = global.oSceneMgr:RandomPos2(mArgs.map_id)
                mArgs.pos_info.x=x
                mArgs.pos_info.y=y
            end
        end
    end
    return mArgs
end

function CTask:SetNeedItem(itemGroupId,iAmount)
    super(CTask).SetNeedItem(self,itemGroupId,iAmount)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        local mOrgTaskInfo = oPlayer.m_oActiveCtrl:GetData("orgtask_taskinfo",{})
        local mPreTaskInfo = mOrgTaskInfo.pretaskinfo
        if mPreTaskInfo and mPreTaskInfo["itemsid"] then
            local itemsid = mPreTaskInfo["itemsid"]
            local itemobj = global.oItemLoader:GetItem(itemsid)
            if itemobj then
                self.m_mNeedItem = {}
                self.m_mNeedItem[itemsid] = 1
            end
        end
    end
end