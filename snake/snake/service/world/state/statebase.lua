local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))

CState = {}
CState.__index = CState
inherit(CState,datactrl.CDataCtrl)

function CState:New(iState)
    local o = super(CState).New(self)
    o.m_iID = iState
    return o
end

function CState:Load(mData)
    mData = mData or {}
    self:SetData("time",mData["time"])
end

function CState:Save()
    local mData = {}
    mData["time"] = self:GetData("time")
    return mData
end

function CState:ValidSave()
    return true
end

function CState:Config(oPlayer,mArgs)
    mArgs = mArgs or {}
    local iTime = mArgs["time"]
    if iTime then
        local iPid = oPlayer.m_iPid
        local iEndTime = iTime + get_time()
        self:SetData("time",iEndTime)
        local func = function ()
            self:TimeOut(iPid)
        end
        if iTime > 0 then
            self:DelTimeCb("timeout")
            self:AddTimeCb("timeout",iTime * 1000,func)
        end
    end
end

function CState:TimeOut(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    assert(oPlayer,string.format("state timeout err:%d %d",iPid,self.m_iID))
    self:DelTimeCb("timeout")
    oPlayer.m_oStateCtrl:RemoveState(self.m_iID)
end

function CState:ID()
    return self.m_iID
end

function CState:IsOutTime()
    local iEndTime = self:GetData("time")
    if not iEndTime or iEndTime == 0 then
        return false
    end
    
    if get_time() < iEndTime then
        return false
    end
    return true
end

function CState:Time()
    return self:GetData("time")
end

function CState:ReConfig(mData)
end

function CState:Name()
    return res["daobiao"]["state"]["state"][self.m_iID]["name"]
end

function CState:Desc()
    return res["daobiao"]["state"]["state"][self.m_iID]["desc"]
end

function CState:MapFlag()
    return res["daobiao"]["state"]["state"][self.m_iID]["flag"]
end

function CState:ReplaceType()
    return res["daobiao"]["state"]["state"][self.m_iID]["replace"]
end

function CState:GetTextData(iText)
    return global.oToolMgr:GetTextData(iText,{"state"})
end

function CState:Click(oPlayer,mData)
end

function CState:GetOtherData()
    return {}
end

function CState:Hide()
    return 0
end

function CState:PackNetInfo()
    return {
        state_id = self.m_iID,
        time = self:GetData("time",0),
        name = self:Name(),
        desc = self:Desc(),
        data = self:GetOtherData(),
        hide = self:Hide(),
    }
end

function CState:Refresh(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CRefreshState",{state_info=self:PackNetInfo()})
end

function CState:LoadEnd(oPlayer)
    local pid = oPlayer:GetPid()
    if self:GetData("time") then
        local iState = self.m_iID
         local func 
         func = function ()
            _TimeOut(pid,iState)
        end
        local iTime = self:GetData("time") - get_time()
        if iTime > 0 then
            self:AddTimeCb("timeout",iTime * 1000,func)
        else
            oPlayer.m_oStateCtrl:RemoveState(self:ID())
            return
        end
    end
    self:OnAddState(oPlayer)
end

function CState:OnAddState(oPlayer)

end

function CState:OnRemoveState(oPlayer)
end

function CState:GetConfigData()
    return res["daobiao"]["state"]["state"][self.m_iID]
end

function NewState(iState)
    local o = CState:New(iState)
    return o
end

function _TimeOut(pid,iState)
    local oWorldMgr =global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oState = oPlayer.m_oStateCtrl:GetState(iState)
    if not oState then return end
    oState:TimeOut(pid)
end
