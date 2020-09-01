local global = require "global"
local record = require "public.record"

local baseofflinectrl = import(service_path("offline.baseofflinectrl"))

local QS_STATE = {
    QUESTION = 1,
    READ =2,
    ANSWER = 3,
    PUSH = 4,
}

local MAXSHOW = 10

CFeedBackCtrl = {}
CFeedBackCtrl.__index = CFeedBackCtrl
inherit(CFeedBackCtrl, baseofflinectrl.CBaseOfflineCtrl)

function CFeedBackCtrl:New(pid)
    local o = super(CFeedBackCtrl).New(self, pid)
    o.m_sDbFlag = "FeedBack"
    o.m_lQuestionList = {}
    o.m_iCurQuestion = 0
    o.m_iCheckState = 1
    return o
end

function CFeedBackCtrl:Release()
    self.m_lQuestionList = {}
    super(CFeedBackCtrl).Release(self)
end

function CFeedBackCtrl:Save()
    local mData = {}
    mData.cur_question = self.m_iCurQuestion
    mData.question_list = self.m_lQuestionList
    mData.check_state = self.m_iCheckState
    return mData
end

function CFeedBackCtrl:Load(mData)
    if not mData then return end

    self.m_iCurQuestion = mData.cur_question or 0
    self.m_lQuestionList = mData.question_list or {}
    self.m_iCheckState = mData.check_state or 1
end

function CFeedBackCtrl:DispatchId()
    self:Dirty()
    self.m_iCurQuestion = self.m_iCurQuestion + 1
    table.insert(self.m_lQuestionList, self.m_iCurQuestion)
    self.m_iCheckState = 1

    return self.m_iCurQuestion
end

function CFeedBackCtrl:GetQuestionListInfo()
    local iCount = table_count(self.m_lQuestionList)
    return iCount, self.m_lQuestionList[1]
end

function CFeedBackCtrl:DelStartId()
    table.remove(self.m_lQuestionList, 1)
end

function CFeedBackCtrl:C2GSFeedBackSetCheckState()
    self.m_iCheckState = 0
end

function CFeedBackCtrl:OnLogin(oPlayer, bReEnter)  
    self:RefreshAllQuestion(oPlayer, self.m_lQuestionList)
end

function CFeedBackCtrl:RefreshAllQuestion(oPlayer, lQuestion)
    if not global.oToolMgr:IsSysOpen("FEEDBACK", nil, true) then return end
    local iPid = oPlayer:GetPid()
    lQuestion = lQuestion or self.m_lQuestionList 
    if not next(lQuestion) then
        oPlayer:Send("GS2CFeedBackAnswerList", {check_state = self.m_iCheckState})
    end
    global.oFeedBackMgr:LoadQuestionList(iPid, lQuestion, function(iPid, lQuestion)
        self:RefreshAllQuestion2(iPid, lQuestion)
    end)
end

function CFeedBackCtrl:RefreshAllQuestion2(iPid, lQuestion)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lQuestionNet = {}
    for _, id in ipairs(lQuestion) do
        local oQuestion = global.oFeedBackMgr:GetQuestion(iPid, id)
        if oQuestion then
            if oQuestion:GetState() == QS_STATE.ANSWER then
                oQuestion:SetState(QS_STATE.PUSH)
                oQuestion:DoSave()
            end
            table.insert(lQuestionNet, oQuestion:PackNet())
        end
    end
    oPlayer:Send("GS2CFeedBackAnswerList", {question_list = lQuestionNet, check_state = self.m_iCheckState})
end

function CFeedBackCtrl:SetFeedBackState(id , sAnswerer, sAnswer)
    if id ~= self.m_iCurQuestion then return end

    global.oFeedBackMgr:LoadQuestion(self:GetPid(), id, function(oQuestion)
        self:SetFeedBackState2(oQuestion, sAnswerer, sAnswer)
    end)
end

function CFeedBackCtrl:SetFeedBackState2(oQuestion, sAnswerer, sAnswer)
    if not oQuestion or oQuestion:GetState() == QS_STATE.PUSH then
        return
    end
    oQuestion:SetAnswer(sAnswer)
    oQuestion:SetAnswererTime()
    oQuestion:SetAnswerer(sAnswerer)

    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    if not sAnswer then
       oQuestion:SetState(QS_STATE.READ)
    elseif not oPlayer then
        oQuestion:SetState(QS_STATE.ANSWER)
    else
        oQuestion:SetState(QS_STATE.PUSH)
    end

    oQuestion:DoSave()

    if oPlayer then
        self:RefreshAllQuestion(oPlayer, {oQuestion:GetId()})
    end
end
