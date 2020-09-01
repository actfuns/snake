local global = require "global"
local res = require "base.res"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))
local defines = import(service_path("fuben.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewProgress(...)
    local o = CProgress:New(...)
    return o
end

CProgress = {}
CProgress.__index = CProgress
inherit(CProgress, datactrl.CDataCtrl)

function CProgress:New(iPid)
    local o = super(CProgress).New(self)
    o:Init(iPid)
    return o
end

function CProgress:Init(iPid)
    self.m_iPid = iPid
end

function CProgress:SetFubenProgress(iFuben, iStep)
    local oTimeCtrl = self:GetTimeCtrl(iFuben)
    local sFlag = string.format("fuben_step_%d",iFuben)
    local mData = oTimeCtrl:Query(sFlag,{})
    mData[tostring(iStep)] = 1
    oTimeCtrl:Set(sFlag,mData)
end

function CProgress:ClearFubenProgress(iFuben)
    local oTimeCtrl = self:GetTimeCtrl(iFuben)
    local sFlag = string.format("fuben_step_%d",iFuben)
    oTimeCtrl:Delete(sFlag)
end

function CProgress:GetFubenStep(iFuben)
    local sFlag = string.format("fuben_step_%d",iFuben)
    local oTimeCtrl = self:GetTimeCtrl(iFuben)
    local mData = oTimeCtrl:Query(sFlag,{})
    local mFuben = self:GetFubenConfig(iFuben)  
    for iStep, _ in ipairs(mFuben.group_list) do
        if not mData[tostring(iStep)] then
            return iStep
        end
    end
    oTimeCtrl:Delete(sFlag)
    return  1
end

function CProgress:GetTimeCtrl(iFuben)
    local oPlayer = self:GetPlayer()
    local mData = self:GetFubenConfig(iFuben)
    if mData.refresh_type == defines.FUBEN_REFRESH_DAY then
        return oPlayer.m_oTodayMorning
    else
        return oPlayer.m_oWeekMorning
    end
end

function CProgress:SetFubenReward(iFuben, iStep)
    local sKey = string.format("fuben_reward_%d_%d", iFuben, iStep)
    local oTimeCtrl = self:GetTimeCtrl(iFuben)
    local iCount = oTimeCtrl:Query(sKey,0)
    oTimeCtrl:Set(sKey,iCount+1)
    self:RefreshFubenReward(iFuben)
end

function CProgress:GetFubenReward(iFuben, iStep)
    local sKey = string.format("fuben_reward_%d_%d", iFuben, iStep)
    local oTimeCtrl = self:GetTimeCtrl(iFuben)
    return oTimeCtrl:Query(sKey,0)
end

function CProgress:GetFubenRewardCnt(iFuben)
    local iCnt = 0
    local mFuben = self:GetFubenConfig(iFuben)
    for iStep, _ in pairs(mFuben.group_list) do
        iCnt = iCnt + self:GetFubenReward(iFuben, iStep)
    end
    return iCnt
end

function CProgress:HasDoneFuben(iFuben)
    return false
end

function CProgress:GetPlayer()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self.m_iPid)
end

function CProgress:GetFubenConfig(iFuben)
    return res["daobiao"]["fuben"]["fuben_config"][iFuben]
end

-- TODO 可能加难度参数（侠影等）
function CProgress:FireFubenDone(iFubenId)
    self:TriggerEvent(gamedefines.EVENT.FUBEN_DONE, {fubenId = iFubenId})
end

function CProgress:RefreshFubenReward(iFuben)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local mConfig = res["daobiao"]["fuben"]["fuben_config"]
    local lFuben = iFuben and {iFuben} or table_key_list(mConfig)
    local lFubenReward = {}
    for _, iFuben in pairs(lFuben) do
        local mUnit = {
            fuben_id = iFuben,
            reward_cnt = self:GetFubenRewardCnt(iFuben),
        }
        table.insert(lFubenReward, mUnit)
    end
    oPlayer:Send("GS2CRefreshFubenRewardCnt", {reward_list=lFubenReward})
end

function CProgress:OnLogin(oPlayer, bReEnter)
    self:RefreshFubenReward()
end

function CProgress:NewHour5(mNow)
    self:RefreshFubenReward()
end

function NewTeamSure(...)
    local o = CTeamSure:New(...)
    return o
end

CTeamSure = {}
CTeamSure.__index = CTeamSure
inherit(CTeamSure, logic_base_cls())

function CTeamSure:New(iTeam)
    local o = super(CTeamSure).New(self)
    o:Init(iTeam)
    return o
end

function CTeamSure:Init(iTeam)
    self.m_iTeam = iTeam
    self.m_iDelay = 60
    self.m_mSure = {}
    self.m_mSession = {}
    self.m_iStartTime = 0
    self.m_iCurFuben = 0
end

function CTeamSure:Release()
    self:DelTimeCb("TimeOut")
    self.m_mSure = {}
    self.m_mSession = {}
    super(CTeamSure).Release(self)
end

function CTeamSure:OnLogin(oPlayer)
    local pid = oPlayer:GetPid()
    if not self.m_mSession[pid] then
        return
    end
    local iFuben = self.m_iCurFuben
    local mData = {}
    mData.fuben = iFuben
    mData.time = self.m_iDelay + self.m_iStartTime - get_time()
    mData.plist = self:GetComfirmInfo(iFuben)
    mData.sessionidx = self.m_mSession[pid]
    oPlayer:Send("GS2CFBComfirm",mData)
end

function CTeamSure:SetEnterSure(iFuben, iPid)
    table_set_depth(self.m_mSure, {iFuben}, iPid, 1)
end

function CTeamSure:GetEnterSure(iFuben, iPid)
    return table_get_depth(self.m_mSure, {iFuben, iPid})
end

function CTeamSure:GetNeedSurePid(iFuben)
    local mData = self:GetFubenConfig(iFuben)
    if mData.sure_type == defines.FUBEN_ENTER_NO_SURE then
        return {}
    elseif mData.sure_type == defines.FUBEN_ENTER_TEAM_SURE then
        local oTeam = self:GetTeam()
        local lMember = oTeam:GetTeamMember()
        local lNeed = {}
        for _, iPid in ipairs(lMember) do
            if not self:GetEnterSure(iFuben, iPid) then
                table.insert(lNeed, iPid)
            end
        end
        return lNeed
    end
end

function CTeamSure:AutoEnterSure(iFuben)
    local oTeam = self:GetTeam()
    if not oTeam then return end

    local oLeader = oTeam:GetLeaderObj()
    if not oLeader then return end

    local oFriend = oLeader:GetFriend()
    self:SetEnterSure(iFuben, oLeader:GetPid())
    local lMember = oTeam:GetTeamMember()
    for _, iPid in ipairs(lMember) do
        if oFriend:IsBothFriend(iPid) then
            self:SetEnterSure(iFuben, iPid)
        end
    end
end

function CTeamSure:CheckEnterSure(iFuben, iConfirm,pid)
    if not pid then
        local oTeam = self:GetTeam()
        if not oTeam then return end
        local lNeed = self:GetNeedSurePid(iFuben)
        if #lNeed < 1 then return true end

        if iConfirm then
            self:GiveConfirm(iFuben)
        end
        return false
    else
        if self:GetEnterSure(iFuben,pid) == 1 then
            return true
        else
            self:GiveSingleConfirm(iFuben,pid)
            return false
        end
    end
end

function CTeamSure:GetComfirmInfo(iFuben)
    local oTeam = self:GetTeam()
    local lMember = oTeam:GetTeamMember()
    local mResult = {}
    for _, pid in ipairs(lMember) do
        local iState = self:GetEnterSure(iFuben,pid) or 0
        table.insert(mResult,{pid = pid,state = iState})
    end
    return mResult
end

function CTeamSure:GiveConfirm(iFuben)
    local oTeam = self:GetTeam()
    local oCbMgr = global.oCbMgr
    local mData = {}
    mData.fuben = iFuben
    mData.time = self.m_iDelay
    mData.plist = self:GetComfirmInfo(iFuben)
    self.m_iStartTime = get_time()
    self.m_iCurFuben = iFuben
    
    local f = function(oPlayer, mData)
        local iFuben = iFuben
        _AnswerBack(oPlayer,mData,iFuben)
    end

    for _, iPid in ipairs(oTeam:GetTeamMember()) do
        local iSession = oCbMgr:SetCallBack(iPid, "GS2CFBComfirm", mData, nil, f)
        self.m_mSession[iPid] = iSession
    end
    
    self:DelTimeCb("TimeOut")
    local iTeamID = self.m_iTeam
    self:AddTimeCb("TimeOut", (self.m_iDelay+1)*1000, function ()
        _TimeOut(iTeamID)
    end)
end

function CTeamSure:AnswerCallBack(oPlayer, iFuben, iSession, iAnswer)
    self:DelTimeCb("AnswerCallBack")
    local oTeam = self:GetTeam()
    local iPid = oPlayer:GetPid()
    if not oTeam then return end
    
    if self.m_mSession[iPid] ~= iSession then
        return
    end
    if self:GetEnterSure(iFuben,iPid)  == 1 then
        return
    end
    if oPlayer:InWar() then
        local sMsg = global.oToolMgr:GetTextData(1006, {"fuben"})
        global.oNotifyMgr:Notify(iPid,sMsg)
        oPlayer:Send("GS2CFBComfirmEnter",{pid = iPid,sessionidx = iSession})
        return 
    end
    if iAnswer ~= 1 then
        local sMsg = string.format("队伍中的%s放弃进入副本", oPlayer:GetName())
        self:BroadNotify(sMsg)
        self:FailEnter()
        return
    end

    self:SetEnterSure(iFuben, iPid)
    for target , iSession in pairs(self.m_mSession) do
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(target)
        if oTarget then
            oTarget:Send("GS2CFBComfirmEnter",{pid = iPid,sessionidx = iSession})
        end
    end
    local oLeader = oTeam:GetLeaderObj() 
    if self:CheckEnterSure(iFuben) then
        self:DelTimeCb("TimeOut")
        self.m_mSession = {}
        local oFubenMgr = global.oFubenMgr
        oFubenMgr:TryStartFuben(oLeader, iFuben)
    end
end

function CTeamSure:TimeOut()
    self:DelTimeCb("TimeOut")
    local lResult ={}
    for pid , iSessionidx in pairs(self.m_mSession) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        local iState = self:GetEnterSure(self.m_iCurFuben,pid) or 0
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

function CTeamSure:GetTeam()
    local oTeamMgr = global.oTeamMgr
    return oTeamMgr:GetTeam(self.m_iTeam)
end

function CTeamSure:GetFubenConfig(iFuben)
    return res["daobiao"]["fuben"]["fuben_config"][iFuben]
end

function CTeamSure:FailEnter()
    self:DelTimeCb("TimeOut")
    for pid , iSessionidx in pairs(self.m_mSession) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CCloseFBComfirm",{sessionidx = iSessionidx})
        end
    end
    self.m_mSession = {}
    self.m_iStartTime = 0
    self.m_iCurFuben = 0
end

function CTeamSure:OnLeaveTeam(pid,flag,oMem)
    if self.m_iCurFuben == 0 then
        return
    end
    if not self.m_mSession[pid] then
        return
    end
    local oTeam = self:GetTeam()
    local sText
    if oMem then
        sText = string.format("%s离开了队伍，请重新确认",oMem:GetName())
        self:BroadNotify(sText)
    end
    self:FailEnter()
end

function CTeamSure:OnEnterTeam(pid,flag)
    if self.m_iCurFuben == 0 then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local oTeam = self:GetTeam()
    local sText = string.format("%s加入了队伍，请重新确认",oPlayer:GetName())
    self:BroadNotify(sText)
    self:FailEnter()
end

function CTeamSure:BroadNotify(sText)
    local oChatMgr = global.oChatMgr
    local oTeam = self:GetTeam()
    for pid,_ in pairs(self.m_mSession) do
        global.oNotifyMgr:Notify(pid, sText)
    end
    if oTeam then
        oChatMgr:HandleTeamChat(oTeam:GetLeaderObj(), sText, true)
    end
end

function CTeamSure:GiveSingleConfirm(iFuben,pid)
    local mData = self:GetFubenConfig(iFuben)
    local oWorldMgr = global.oWorldMgr
    local oCbMgr = global.oCbMgr
    local oToolMgr = global.oToolMgr
    local oUIMgr = global.oUIMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local oTeam = self:GetTeam()
    if not oTeam then return end
    local sContent = oToolMgr:GetTextData(1004, {"fuben"})
    local oLeader = oTeam:GetLeaderObj()
    if not oLeader then return end
    local oFuben = oLeader:IsInFuBen()
    if not oFuben then return end
    local iWarCount = oFuben:GetWarCount()
    sContent = oToolMgr:FormatColorString(sContent,{warcount = iWarCount,name=mData.name})
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
            _SingelConfirmEnter(oPlayer,iFuben,oTeam:TeamID())
        end
    end)
end

function _TimeOut(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oTeam =  oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end
    oTeam.m_oFubenSure:TimeOut()
end

function _AnswerBack(oPlayer,mData,iFuben)
    local iAnswer = mData.answer
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    oTeam.m_oFubenSure:AnswerCallBack(oPlayer, iFuben, mData.sessionidx, iAnswer)
end

function _SingelConfirmEnter(oPlayer,iFuben,iTeamID)
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    local oTeamMgr = global.oTeamMgr
    if not oTeam then return end
    if oTeam:TeamID() ~= iTeamID then return end
    oTeam.m_oFubenSure:SetEnterSure(iFuben,pid)
    if oTeam:IsShortLeave(pid) then
        oTeamMgr:TeamBack(oPlayer)
    end
end
