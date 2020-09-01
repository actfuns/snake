--import module

local global = require "global"
local skynet = require "skynet"

local tableop = import(lualib_path("base.tableop"))
local gamedefines = import(lualib_path("public.gamedefines"))
local statusbase = import(service_path("statusbase"))


function NewStatusMgr(...)
    local o = CStatusMgr:New(...)
    return o
end

CStatusMgr = {}
CStatusMgr.__index = CStatusMgr
inherit(CStatusMgr, logic_base_cls())

function CStatusMgr:New(iWarId,iWid)
    local o = super(CStatusMgr).New(self)
    o.m_iWarId = iWarId
    o.m_iWid = iWid
    o.m_mStauts = {}
    return o
end

function CStatusMgr:Release()
    for _,oStatus in pairs(self.m_mStauts) do
        baseobj_safe_release(oStatus)
    end
    self.m_mStauts = {}
    super(CStatusMgr).Release(self)
end

function CStatusMgr:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self.m_iWarId)
end

function CStatusMgr:GetWarrior()
    local oWar = self:GetWar()
    return oWar:GetWarrior(self.m_iWid)
end

function CStatusMgr:AddStatus(iStatus, mAgrs)
    local o = statusbase.NewStatus(iStatus, mAgrs)
    self.m_mStauts[iStatus] = o
    local oAction = self:GetWarrior()
    if oAction then
        oAction:SendAll("GS2CWarUpdateStatus", {
            war_id = self.m_iWarId,
            wid = self.m_iWid,
            status = o:PackUnit(),
        })
        local oWar = oAction:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n增加status#R%s#n", oAction:GetName(), o.m_ID))
    end
end

function CStatusMgr:RemoveStatus(iStatus, oAction)
    local oStatus = self.m_mStauts[iStatus]
    if not oStatus then return end

    self.m_mStauts[iStatus] = nil
    baseobj_delay_release(oStatus)

    oAction = oAction or self:GetWarrior()
    if oAction then
        oAction:SendAll("GS2CWarDelStatus", {
            war_id = self.m_iWarId,
            wid = self.m_iWid,
            status_id = oStatus.m_ID,
        })
        local oWar = oAction:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n移除status#R%s#n", oAction:GetName(), oStatus.m_ID))
    end
end

function CStatusMgr:GetStatus(iStatus)
    return self.m_mStauts[iStatus]
end

function CStatusMgr:GetAllStatus()
    return self.m_mStauts
end

function CStatusMgr:UpdateStatus(iStatus, mAgrs, bReset)
    local oStatus = self.m_mStauts[iStatus]
    if not oStatus then return end

    oStatus:Update(mAgrs, bReset)
    local oAction = self:GetWarrior()
    if oAction then
        oAction:SendAll("GS2CWarUpdateStatus", {
            war_id = self.m_iWarId,
            wid = self.m_iWid,
            status = oStatus:PackUnit(),
        })
        local oWar = oAction:GetWar()
        oWar:AddDebugMsg(string.format("#B%s#n更新status#R%s#n", oAction:GetName(), oStatus.m_ID))
    end
end



