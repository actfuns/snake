--离线档案
local skynet = require "skynet"
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"

local defines = import(service_path("offline.defines"))
local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl


CPrivacyCtrl = {}
CPrivacyCtrl.__index = CPrivacyCtrl
inherit(CPrivacyCtrl, CBaseOfflineCtrl)

function CPrivacyCtrl:New(iPid)
    local o = super(CPrivacyCtrl).New(self, iPid)
    o.m_sDbFlag = "Privacy"
    o.m_lFuncList = {}
    o.m_mOrders = {}
    return o
end

function CPrivacyCtrl:Save()
    local data = {}
    data["func_list"] = self.m_lFuncList or {}
    data["orders"] = self.m_mOrders or {}
    return data
end

function CPrivacyCtrl:Load(data)
    data = data or {}
    self.m_lFuncList = data["func_list"] or {}
    self.m_mOrders = data["orders"] or {}
end

function CPrivacyCtrl:OnLogin(oPlayer, bReEnter)
    self:Dirty()
    local funclist = self.m_lFuncList
    self.m_lFuncList = {}
    local oBackendMgr = global.oBackendMgr
    for _, mFuncData in ipairs(funclist) do
        local iFuncNo, mArgs = table.unpack(mFuncData)
        local sFunc = defines.GetFuncByNo(iFuncNo)
        if iFuncNo < 10000 then
            oPlayer[sFunc](oPlayer, table.unpack(mArgs))
        elseif iFuncNo < 11000 then
            oBackendMgr[sFunc](oBackendMgr, oPlayer, table.unpack(mArgs))
        elseif iFuncNo < 12000 then
            defines.mOnlineExecute[sFunc](oPlayer, table.unpack(mArgs))
        end
    end
end

function CPrivacyCtrl:AddDealedOrder(iOrderId)
    self:Dirty()
    self.m_mOrders[db_key(iOrderId)] = 1
end

function CPrivacyCtrl:IsDealedOrder(iOrderId)
    return self.m_mOrders[db_key(iOrderId)]
end

function CPrivacyCtrl:AddFunc(sFunc, mArgs)
    local iFuncNo = defines.GetFuncNo(sFunc)
    assert(iFuncNo>0,string.format("%d AddFuncList err:%s", self:GetPid(), sFunc))
    table.insert(self.m_lFuncList,{iFuncNo, mArgs})
    self:Dirty()
end
