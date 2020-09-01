local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local taskdefines = import(service_path("task/taskdefines"))


function NewJYFubenSure(...)
    local o = CJYFubenSure:New(...)
    return o
end

CJYFubenSure = {}
CJYFubenSure.__index = CJYFubenSure
inherit(CJYFubenSure, logic_base_cls())

function CJYFubenSure:New(iTeam)
    local o = super(CJYFubenSure).New(self)
    o:Init(iTeam)
    return o
end

function CJYFubenSure:Init(iTeam)
    self.m_iTeam = iTeam
    self.m_iDelay = 60
    self.m_mSure = {}
    self.m_mSession = {}
    self.m_iStartTime = 0
    self.m_iModel = 0
end

function CJYFubenSure:Release()
    self:DelTimeCb("TimeOut")
    self.m_mSure = {}
    self.m_mSession = {}
    super(CJYFubenSure).Release(self)
end

function CJYFubenSure:OnLogin(oPlayer)
    if self.m_iStartTime  == 0 then return end
    local pid = oPlayer:GetPid()
    if not self.m_mSession[pid] then
        return
    end
    local mData = {}
    mData.time =  self.m_iDelay + self.m_iStartTime - get_time()
    mData.plist = self:GetComfirmInfo()
    mData.sessionidx = self.m_mSession[pid]
    oPlayer:Send("GS2CJYFBComfirm",mData)
end

function CJYFubenSure:SetEnterSure(pid)
    self.m_mSure[pid] = 1
end

function CJYFubenSure:GetEnterSure(pid)
    return self.m_mSure[pid]
end

function CJYFubenSure:GetNeedSurePid()
    local oTeam = self:GetTeam()
    local lMember = oTeam:GetTeamMember()
    local lNeed = {}
    for _, pid in ipairs(lMember) do
        if not self:GetEnterSure(pid) then
            table.insert(lNeed, pid)
        end
    end
    return lNeed
end

function CJYFubenSure:AutoEnterSure()
    local oTeam = self:GetTeam()
    if not oTeam then return end

    local oLeader = oTeam:GetLeaderObj()
    if not oLeader then return end

    local oFriend = oLeader:GetFriend()
    self:SetEnterSure(oLeader:GetPid())
    local lMember = oTeam:GetTeamMember()
    for _, iPid in ipairs(lMember) do
        if oFriend:IsBothFriend(iPid) then
            self:SetEnterSure(iPid)
        end
    end
end

function CJYFubenSure:CheckEnterSure(pid)
    local oTeam = self:GetTeam()
    if not oTeam then 
        return false 
    end
    
    if not pid then
        local lNeed = self:GetNeedSurePid()
        if #lNeed < 1 then 
            return true 
        end
        self:GiveConfirm()
        return false
    else
        if self:GetEnterSure(pid) == 1 then
            return true
        else
            self:GiveSingleConfirm(pid)
            return false
        end
    end
end

function CJYFubenSure:GetComfirmInfo()
    local oTeam = self:GetTeam()
    local lMember = oTeam:GetTeamMember()
    local mResult = {}
    for _, pid in ipairs(lMember) do
        local iState = self:GetEnterSure(pid) or 0
        table.insert(mResult,{pid = pid,state = iState})
    end
    return mResult
end

function CJYFubenSure:GiveConfirm()
    local oTeam = self:GetTeam()
    local oCbMgr = global.oCbMgr
    local mData = {}
    mData.time = self.m_iDelay
    mData.plist = self:GetComfirmInfo()
    self.m_iStartTime = get_time()
    
    local f = function(oPlayer, mData)
        _AnswerBack(oPlayer,mData)
    end

    for _, pid in ipairs(oTeam:GetTeamMember()) do
        local iSession = oCbMgr:SetCallBack(pid, "GS2CJYFBComfirm", mData, nil, f)
        self.m_mSession[pid] = iSession
    end
    
    self:DelTimeCb("TimeOut")
    local iTeamID = self.m_iTeam
    self:AddTimeCb("TimeOut", (self.m_iDelay+1)*1000, function ()
        _TimeOut(iTeamID)
    end)
end

function CJYFubenSure:AnswerCallBack(oPlayer, iSession, iAnswer)
    self:DelTimeCb("AnswerCallBack")
    local oTeam = self:GetTeam()
    local pid = oPlayer:GetPid()
    if not oTeam then return end
    
    if self.m_mSession[pid] ~= iSession then
        return
    end
    if self:GetEnterSure(pid)  == 1 then
        return
    end
    if oPlayer:InWar() then
        local sMsg = global.oToolMgr:GetTextData(1006, {"fuben"})
        global.oNotifyMgr:Notify(pid,sMsg)
        oPlayer:Send("GS2CFBComfirmEnter",{pid = pid,sessionidx = iSession})
        return 
    end
    if iAnswer ~= 1 then
        local sMsg = string.format("队伍中的%s放弃进入副本", oPlayer:GetName())
        self:BroadNotify(sMsg)
        self:FailEnter()
        return
    end

    self:SetEnterSure(pid)
    for target , iSession in pairs(self.m_mSession) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(target)
        oTarget:Send("GS2CJYFBComfirmEnter",{pid = pid,sessionidx = iSession})
    end
    if self:CheckEnterSure() then
        self:SuccEnter()
    end
end

function CJYFubenSure:TimeOut()
    self:DelTimeCb("TimeOut")
    local lResult ={}
    for pid , iSessionidx in pairs(self.m_mSession) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local iState = self:GetEnterSure(pid) or 0
        if oPlayer and  iState == 0 then
            table.insert(lResult,oPlayer:GetName())
        end
    end
    if #lResult > 0 then
        local sMsg = string.format("队伍中的#G%s#n没有确认", table.concat(lResult, "、"))
        self:BroadNotify(sMsg)
    end
    self:FailEnter()
end

function CJYFubenSure:GetTeam()
    local oTeamMgr = global.oTeamMgr
    return oTeamMgr:GetTeam(self.m_iTeam)
end

function CJYFubenSure:FailEnter()
    self:DelTimeCb("TimeOut")
    for pid , iSessionidx in pairs(self.m_mSession) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CCloseJYFBComfirm",{sessionidx = iSessionidx})
        end
    end
    self.m_mSession = {}
    self.m_iStartTime = 0
end

function CJYFubenSure:SuccEnter()
    self:DelTimeCb("TimeOut")
    for pid , iSessionidx in pairs(self.m_mSession) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CCloseJYFBComfirm",{sessionidx = iSessionidx})
        end
    end
    self.m_mSession = {}
    self.m_iStartTime = 0
    local oTeam  = self:GetTeam()
    if oTeam then
        local oHD = global.oHuodongMgr:GetHuodong("jyfuben")
        oHD:JoinGame(oTeam:GetLeaderObj())
    end
end

function CJYFubenSure:OnLeaveTeam(pid,flag,oMem)
    local oTeam = self:GetTeam()
    if not oTeam then return end
    local oPlayer  = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local oHD = global.oHuodongMgr:GetHuodong("jyfuben")
        if oHD then
            oHD:OnLeaveTeam(oPlayer,flag,self.m_iTeam)
        end
    end
    if flag == 1 then
        self.m_mSure[pid] = nil
    end
    if self.m_iStartTime == 0 then return end
    if not self.m_mSession[pid] then
        return
    end
    local sText
    if oMem then
        local sText = string.format("%s离开了队伍，请重新确认",oMem:GetName())
        self:BroadNotify(sText)
    end
    self:FailEnter()
end

function CJYFubenSure:OnEnterTeam(pid,flag)
    local oTeam = self:GetTeam()
    if not oTeam then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local oHD = global.oHuodongMgr:GetHuodong("jyfuben")
        if oHD then
            oHD:OnEnterTeam(pid,flag,oTeam)
        end
    end
    if self.m_iStartTime == 0 then return end
    local sText = string.format("%s加入了队伍，请重新确认",oPlayer:GetName())
    self:BroadNotify(sText)
    self:FailEnter()
end

function CJYFubenSure:BroadNotify(sText)
    local oChatMgr = global.oChatMgr
    local oTeam = self:GetTeam()
    for pid,_ in pairs(self.m_mSession) do
        global.oNotifyMgr:Notify(pid, sText)
    end
    if oTeam then
        oChatMgr:HandleTeamChat(oTeam:GetLeaderObj(), sText, true)
    end
end

function CJYFubenSure:GiveSingleConfirm(pid)
    local oWorldMgr = global.oWorldMgr
    local oCbMgr = global.oCbMgr
    local oToolMgr = global.oToolMgr
    local oUIMgr = global.oUIMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oTeam = self:GetTeam()
    if not oTeam then return end
    local sContent = oToolMgr:GetTextData(1003,{"huodong","jyfuben"})
    local oHD = global.oHuodongMgr:GetHuodong("jyfuben")
    local iCurFloor = oHD:GetCurFloor(oTeam)
    sContent = oToolMgr:FormatColorString(sContent,{floor = iCurFloor})
     local mData = {
        sContent = sContent ,
        sConfirm = "确认",
        sCancle = "取消",
        default = 1,
        time = 60,
    }
    local mData = oCbMgr:PackConfirmData(nil, mData)   
    oCbMgr:SetCallBack(pid, "GS2CConfirmUI",mData,nil,function (oPlayer,mData)
        local iAnswer = mData["answer"]
        if iAnswer == 1 then
            _SingelConfirmEnter(oPlayer,oTeam:TeamID())
        end
    end)
end

function _TimeOut(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oTeam =  oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end
    oTeam.m_oJYFubenSure:TimeOut()
end

function _AnswerBack(oPlayer,mData)
    local iAnswer = mData.answer
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    oTeam.m_oJYFubenSure:AnswerCallBack(oPlayer, mData.sessionidx, iAnswer)
end

function _SingelConfirmEnter(oPlayer,iTeamID)
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    local oTeamMgr = global.oTeamMgr
    if not oTeam then return end
    if oTeam:TeamID() ~= iTeamID then return end
    oTeam.m_oJYFubenSure:SetEnterSure(pid)
    if oTeam:IsShortLeave(pid) then
        oTeamMgr:TeamBack(oPlayer)
    end
end
