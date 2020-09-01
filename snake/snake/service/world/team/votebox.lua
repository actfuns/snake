--import module
local global = require "global"
local extend = require "base.extend"
local record = require "public.record"

function NewVoteBox(...)
    return CVoteBox:New(...)
end

local FULL_VOTE = -1

CVoteBox = {}
CVoteBox.__index = CVoteBox
inherit(CVoteBox,logic_base_cls())

function CVoteBox:New(sTopic, oPlayer, oTeam, bLeave, iPassCnt,defalut,time)
    local o = super(CVoteBox).New(self)
    oTeam.m_oVoteBox = o
    o.m_iPID = oPlayer:GetPid()
    o.m_sName = oPlayer:GetName()
    o.m_iTeamID = oTeam.m_ID
    o.m_sTopic = sTopic
    o.m_iDefault = defalut
    o.m_bLeave = bLeave
    if bLeave then
        o.m_lMember = extend.Table.keys(oTeam:OnlineMember())
    else
        o.m_lMember = oTeam:GetTeamMember()
    end
    extend.Array.remove(o.m_lMember, oPlayer:GetPid())
    o.m_mVoteResult = {}
    o.m_iPassCnt = iPassCnt      --  -1.全票通过，2.通过人数
    o.m_bEnd = false
    o.HandleEnd = nil
    o.m_lSessionidx = {}
    o.m_iTime = time
    return o
end

function CVoteBox:GetPlayer()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self.m_iPID)
end

function CVoteBox:GetTeam()
    local oTeamMgr = global.oTeamMgr
    return  oTeamMgr:GetTeam(self.m_iTeamID)
end

function CVoteBox:ValidStart()
    if self.m_iPassCnt ~= FULL_VOTE then
        if self.m_iPassCnt>#self.m_lMember or self.m_iPassCnt<#self.m_lMember then
            assert(nil,string.format("%s %s passcnt error %s %s",self.m_iPID,self.m_sTopic,self.m_iPassCnt,#self.m_lMember))
        end
    end
end

function CVoteBox:Start()
    self:ValidStart()
    local oCbMgr = global.oCbMgr
    for _, pid in ipairs(self.m_lMember) do
        local mData = oCbMgr:PackConfirmData(pid, self:ConfirmData())
        local func = function (oPlayer,mData)
            _TeamVote(oPlayer,mData)
        end
        local iSessionidx= oCbMgr:SetCallBack(pid,"GS2CConfirmUI",mData,nil,func)
        self.m_lSessionidx[pid] = iSessionidx
    end

    local func 
    local iTeamID = self.m_iTeamID
    func = function ()
        _ForceEnd(iTeamID)
    end
    self:AddTimeCb("ForceEnd",(self.m_iTime+1)*1000,func)
end

function CVoteBox:ForceEnd()
    self:DelTimeCb("ForceEnd")
    for _,pid in ipairs(self.m_lMember) do
        if not self.m_mVoteResult[pid] then
            if self.m_iDefault == 1 then
                self:Agree(pid)
            else
                self:Refuse(pid)
            end
        end
    end
    self:CheckEnd()
end

function CVoteBox:Vote(pid, iAgree)
    if self.m_bEnd then return end
    if self.m_mVoteResult[pid] then return end
    if not extend.Array.find(self.m_lMember,pid) then return end

    if iAgree == 1 then
        self:Agree(pid)
    else
        self:Refuse(pid)
    end
end

function CVoteBox:Agree(pid)
    self.m_mVoteResult[pid] = 1
    if self.HandleAgree then
        self.HandleAgree(self, pid)
    end
    self:CheckEnd()
end

function CVoteBox:Refuse(pid)
    self.m_mVoteResult[pid] = 0
    if self.HandleRefuse then
        self.HandleRefuse(self, pid)
    end
    if self.m_iPassCnt == FULL_VOTE then
        self:End(false)
        return
    end
    self:CheckEnd()
end

function CVoteBox:CheckEnd()
    if self.m_bEnd then return end

    if self.m_iPassCnt == FULL_VOTE then
        for _, pid in ipairs(self.m_lMember) do
            if self.m_mVoteResult[pid] == 0 then
                self:End(false)
            elseif not self.m_mVoteResult[pid] then
                return
            end
        end
        self:End(true)
    else
        local cnt = 0
        local iAll = 0
        for pid, iAgree in pairs(self.m_mVoteResult) do
            iAll = iAll + 1
            if iAgree == 1 then
                cnt = cnt + 1
                if cnt >= self.m_iPassCnt then
                    self:End(true)
                end
            end
        end
        if iAll >= #self.m_lMember then
            self:End(false)
        end
    end
end

function CVoteBox:End(bResult)
    if self.m_bEnd then return end
    self.m_bEnd = true
    local oTeam = self:GetTeam()
    if oTeam then
        oTeam.m_oVoteBox = nil
    end
    self:CloseComfirmUI()
    self.HandleEnd(self:GetPlayer(), oTeam, bResult)
end

function CVoteBox:ConfirmData()
    if self.CustomConfirmData then
        return self.CustomConfirmData(self.m_sTopic)
    else
        return {
            sContent = self.m_sTopic,
        }
    end
end

function CVoteBox:Answer2Agree(iAnswer)
    if self.CustomAnswer then
        return self.CustomAnswer(iAnswer)
    else
        if iAnswer == 1 then
            return 1
        else
            return 0
        end
    end
end

function CVoteBox:OnLeaveTeam(pid, iFlag)
    if self.m_bEnd then return end
    if self.m_bLeave and iFlag ==2 then return end
    if self.m_iPID == pid then
        self:End(false)
        local oNotifyMgr = global.oNotifyMgr
        local oChatMgr = global.oChatMgr
        local oToolMgr = global.oToolMgr
        local sMode = "放弃"
        if iFlag == 1 then 
            sMode = "离队"
        elseif iFlag ==2 then
            sMode = "暂离"
        end 
        for pid , iSessionidx in pairs (self.m_lSessionidx) do
            oNotifyMgr:Notify(pid, string.format("%s%s了,申请队长失败",self.m_sName,sMode))
        end
        if iFlag==2 then
            oNotifyMgr:Notify(self.m_iPID,"你暂离了，申请队长失败")
        end
        return
    end

    self:Vote(pid,self.m_iDefault)

    local oUIMgr = global.oUIMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid) 
    if oPlayer then
        oUIMgr:GS2CCloseConfirmUI(oPlayer, self.m_lSessionidx[pid])
    end
    self.m_lSessionidx[pid]=nil
end

function CVoteBox:CloseComfirmUI()
    local oUIMgr = global.oUIMgr
    local oWorldMgr = global.oWorldMgr
    for pid , iSessionidx in pairs (self.m_lSessionidx) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid) 
        if oPlayer then
            oUIMgr:GS2CCloseConfirmUI(oPlayer, iSessionidx)
        end
    end
end

function _ForceEnd(iTeamID)
    local oTeamMgr = global.oTeamMgr
    local oTeam = oTeamMgr:GetTeam(iTeamID)
    if not oTeam then return end
    if oTeam.m_oVoteBox then
        oTeam.m_oVoteBox:ForceEnd()
    end
end

function _TeamVote(oPlayer,mData)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end
    if not oTeam.m_oVoteBox then return end
    if oTeam.m_oVoteBox.m_bEnd then return end
    local iAgree = oTeam.m_oVoteBox:Answer2Agree(mData["answer"])
    if oTeam.m_ID ~= oTeam.m_oVoteBox.m_iTeamID then return end
    oTeam.m_oVoteBox:Vote(oPlayer:GetPid(), iAgree)
end