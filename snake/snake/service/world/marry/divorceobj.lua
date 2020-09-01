local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local mdefines = import(service_path("marry.defines"))
local datactrl = import(lualib_path("public.datactrl"))


function NewDivorceObj(...)
    return CDivorceObj:New(...)
end

CDivorceObj = {}
CDivorceObj.__index = CDivorceObj
inherit(CDivorceObj, datactrl.CDataCtrl)

function CDivorceObj:New(iDid)
    local o = super(CDivorceObj).New(self)
    o:Init()
    return o
end

function CDivorceObj:Init()
    self.m_iDid = self:DispatchId()
    self.m_iType = 0
    self.m_iPid1 = 0
    self.m_iPid2 = 0
    self.m_iApplyTime = 0
    self.m_iStatus = 0
    self.m_mSession = {}
end

function CDivorceObj:Create(iType, iPid1, iPid2)
    self.m_iType = iType
    self.m_iPid1 = iPid1
    self.m_iPid2 = iPid2
    self.m_iApplyTime = get_time()
    self.m_iStatus = 0
end

function CDivorceObj:Save()
    local mData = {}
    mData["type"] = self.m_iType
    mData["pid1"] = self.m_iPid1
    mData["pid2"] = self.m_iPid2
    mData["applytime"] = self.m_iApplyTime
    mData["status"] = self.m_iStatus
    return mData   
end

function CDivorceObj:Load(mData)
    if not mData then return end

    self.m_iType = mData["type"]
    self.m_iPid1 = mData["pid1"]
    self.m_iPid2 = mData["pid2"]
    self.m_iApplyTime = mData["applytime"]
    self.m_iStatus = mData["status"]
end

function CDivorceObj:DispatchId()
    return global.oMarryMgr:DispatchDivorceNo()
end

function CDivorceObj:DID()
    return self.m_iDid
end

function CDivorceObj:Type()
    return self.m_iType
end

function CDivorceObj:Pid1()
    return self.m_iPid1
end

function CDivorceObj:Pid2()
    return self.m_iPid2
end

function CDivorceObj:OtherPid(iPid)
    if self:Pid1() == iPid then
        return self:Pid2()
    else
        return self:Pid1()
    end
end

function CDivorceObj:SetSession(iPid, iSession)
    self.m_mSession[iPid] = iSession
end

function CDivorceObj:GetSession(iPid)
    return self.m_mSession[iPid]
end

function CDivorceObj:SetStatus(iStatus)
    self.m_iStatus = iStatus
    self:Dirty()
end

function CDivorceObj:GetStatus()
    if self.m_iStatus == mdefines.DIVORCE_STATUS.NONE then
        return self.m_iStatus
    else
        local iApplyTime = self:GetApplyTime()
        local iTime = global.oMarryMgr:GetDivorceSumbitTime()
        if iApplyTime + iTime - get_time() > 0 then
            return mdefines.DIVORCE_STATUS.SUBMIT
        else
            return mdefines.DIVORCE_STATUS.CONFIRM
        end
    end 
end

function CDivorceObj:GetApplyTime()
    return self.m_iApplyTime
end

function CDivorceObj:CheckTimeCb()
    local iStatus = self:GetStatus()
    if iStatus == mdefines.DIVORCE_STATUS.NONE then
        if get_time() - self:GetApplyTime() > 5*60 then
            global.oMarryMgr:DelDivorce(self)
        end
    else
        local iApplyTime = self:GetApplyTime()
        local iTime = global.oMarryMgr:GetDivorceConfirmTime()
        local iLeftTime = math.max(iApplyTime + iTime - get_time(), 1)

        self:DelTimeCb("_CheckDivorceTimeOut")
        if iLeftTime <= 24*3600 then
            local iDid = self:DID()
            self:AddTimeCb("_CheckDivorceTimeOut", iLeftTime*1000, function ()
                global.oMarryMgr:DoDivorceConfirmTimeOut(iDid)
            end) 
        end
    end
end

function CDivorceObj:SetApplyTimeCB(iSecond, bRemove)
    self:DelTimeCb("_ApplyTimeCb")

    local iDid = self:DID()
    self:AddTimeCb("_ApplyTimeCb", iSecond*1000, function ()
        global.oMarryMgr:DoApplyDivorceTimeOut(iDid, bRemove)
    end)
end

function CDivorceObj:RemoveApplyTimeCB()
    self:DelTimeCb("_ApplyTimeCb")    
end