--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))


CAchieveCtrl = {}
CAchieveCtrl.__index = CAchieveCtrl
inherit(CAchieveCtrl, datactrl.CDataCtrl)

function CAchieveCtrl:New(iPid)
    local o = super(CAchieveCtrl).New(self,{pid=iPid})
    o.m_lOrgReceiveAch = {}
    return o
end

function CAchieveCtrl:GetPid()
    return self:GetInfo("pid")
end

function CAchieveCtrl:Save()
    local mData = {}
    mData.org_ach = self.m_lOrgReceiveAch
    return mData
end

function CAchieveCtrl:Load(mData)
    if not mData then return end

    self.m_lOrgReceiveAch = mData.org_ach or {}
end

function CAchieveCtrl:ReceiveOrgAch(iAch)
    table.insert(self.m_lOrgReceiveAch, iAch)
    self:Dirty()
end

function CAchieveCtrl:HasReceiveOrgAch(iAch)
    return table_in_list(self.m_lOrgReceiveAch, iAch)
end

