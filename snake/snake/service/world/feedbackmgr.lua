local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local router = require "base.router"
local net = require "base.net"
local record = require "public.record"
local gamedb = import(lualib_path("public.gamedb"))
local datactrl = import(lualib_path("public.datactrl"))

function NewFeedBackMgr(...)
    return CFeedBackMgr:New(...)
end

CFeedBackMgr = {}
CFeedBackMgr.__index = CFeedBackMgr
inherit(CFeedBackMgr, logic_base_cls())

local MAXSHOW = 3

function CFeedBackMgr:New()
    local o = super(CFeedBackMgr).New(self)
    o.m_mQuestionList = {}
    return o
end

function CFeedBackMgr:EncodeKey(iPid, iQue)
    return iPid .. "-" .. iQue
end

function CFeedBackMgr:DecodeKey(sKey)
    return split_string(sKey, "-", tonumber)
end

function CFeedBackMgr:LoadQuestion(iPid, id, func)
    local sKey = self:EncodeKey(iPid, id)
    local oQuestion = self.m_mQuestionList[sKey]
    if oQuestion then
        oQuestion:WaitLoaded(func)
    else
        oQuestion = NewQuestion(id, iPid)
        oQuestion:WaitLoaded(func)
        self.m_mQuestionList[sKey] = oQuestion
        
        local mCmd = {
            module = "feedbackdb",
            cmd = "GetQuestion",
            cond = {id = id, pid = iPid},
        }
        gamedb.LoadDb(id, "common", "DbOperate", mCmd, function(mRecord, mData)
            local oQuestion = self.m_mQuestionList[sKey]
            assert(oQuestion and not oQuestion:IsLoaded())
            if mData.success then
                oQuestion:Load(mData.data)
                oQuestion:OnLoaded()
            else
                oQuestion:OnLoadedFail()
            end
        end)
    end
end

function CFeedBackMgr:LoadQuestionList(iPid, lQuestion, func)
    local lLoaded = {}
    for _, id in ipairs(lQuestion) do
        self:LoadQuestion(iPid, id, function()
            table.insert(lLoaded, id)
            if #lLoaded >= #lQuestion then
                safe_call(func, iPid, lQuestion)
            end
        end)
    end
end

function CFeedBackMgr:GetQuestion(iPid, id)
    local sKey = self:EncodeKey(iPid, id)
    return self.m_mQuestionList[sKey]
end

function CFeedBackMgr:GetQuestionByKey(sKey)
    return self.m_mQuestionList[sKey]
end

function CFeedBackMgr:FeedBackQuestion(oPlayer, mInfo)
    local iPid = oPlayer:GetPid()
    local oFeedBackCtrl = global.oWorldMgr:GetFeedBack(iPid)
    local id = oFeedBackCtrl:DispatchId()

    local oQuestion = NewQuestion(id, iPid, mInfo)
    local sKey = self:EncodeKey(iPid, id)
    self.m_mQuestionList[sKey] = oQuestion
    oQuestion:OnLoaded()
    oQuestion:AddSaveMerge(oFeedBackCtrl)
    oQuestion:DoSave()

    oFeedBackCtrl:RefreshAllQuestion(oPlayer, {id})

    --TODO 超过长度删除lQuestionList中的第一项数据, 并释放question对象
    self:HandlePlayerQuestionList(oPlayer)
end

function CFeedBackMgr:HandlePlayerQuestionList(oPlayer)
    local iPid = oPlayer:GetPid()
    local oFeedBackCtrl = global.oWorldMgr:GetFeedBack(iPid)
    local iCount, iStart = oFeedBackCtrl:GetQuestionListInfo()
    if iCount > MAXSHOW then
        local oQuestion = self:GetQuestion(iPid, iStart)
        if not oQuestion then return end
        oFeedBackCtrl:DelStartId()
        oQuestion:Release()
        local sKey = self:EncodeKey(iPid, iStart)
        self.m_mQuestionList[sKey] = nil
    end
end

function CFeedBackMgr:SetFeedBackState(mData)
    if not mData.pid then return end
    local iPid = mData.pid
    global.oWorldMgr:LoadFeedBack(iPid, function(oFeedBackCtrl)
        if oFeedBackCtrl then
            oFeedBackCtrl:SetFeedBackState(mData.id, mData.answerer, mData.answer)
        end
    end)
end


function NewQuestion(...)
    return CQuestion:New(...)
end

CQuestion = {}
CQuestion.__index = CQuestion
inherit(CQuestion, datactrl.CDataCtrl)

function CQuestion:New(id, pid, mInfo)
    local o = super(CQuestion).New(self)
    o.m_iId = id
    o.m_iOwnerPid = pid
    o:Init(pid, mInfo)
    return o
end

function CQuestion:GetId()
    return self.m_iId
end

function CQuestion:Init(pid, mInfo)
    if not mInfo then return end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    self.m_iTime = get_time()
    self.m_iType = mInfo.type
    self.m_sContext = mInfo.context
    self.m_mUrl = mInfo.url_list
    self.m_sQQ_No = mInfo.qq_no
    self.m_sPhone_No = mInfo.phone_no
    self.m_iState = 1
    self.m_mPlayerInfo = self:GetPlayerInfo(oPlayer, mInfo)
    self.m_sAnswer = nil
    self.m_iAnswerTime = nil
    self.m_sAnswerer= nil
end

function CQuestion:Release()
    self.m_mPlayerInfo = nil
    super(CQuestion).Release(self)
end

function CQuestion:GetPlayerInfo(oPlayer, mInfo)
    local mPlayerInfo = {}
    mPlayerInfo.pid = oPlayer:GetPid()
    mPlayerInfo.name = oPlayer:GetName()
    mPlayerInfo.grade = oPlayer:GetGrade()
    mPlayerInfo.school = oPlayer:GetSchool()

    mPlayerInfo.charge = oPlayer:Query("rebate_gold_coin",0)

    mPlayerInfo.platform = oPlayer:GetPlatform()
    mPlayerInfo.channel = oPlayer:GetChannel()
    mPlayerInfo.born_server = oPlayer:GetBornServer()
    mPlayerInfo.now_server = oPlayer:GetNowServer()
    mPlayerInfo.client_version = oPlayer:GetClientVer()

    mPlayerInfo.client_ip = oPlayer:GetIP()
    mPlayerInfo.client_device = oPlayer:GetDevice()
    mPlayerInfo.true_mac = oPlayer:GetTrueMac()
    mPlayerInfo.client_os = oPlayer:GetClientOs()
    mPlayerInfo.net_type = mInfo.net_type
    mPlayerInfo.signal_strength = mInfo.signal_strength
    return mPlayerInfo
end

function CQuestion:SetState(iState)
    self:Dirty()
    self.m_iState = iState
end

function CQuestion:SetAnswerer(sAnswerer)
    self:Dirty()
    self.m_sAnswerer = sAnswerer
end

function CQuestion:GetState()
    return self.m_iState
end

function CQuestion:SetAnswer(sAnswer)
    self:Dirty()
    self.m_sAnswer = sAnswer
end

function CQuestion:GetAnswer()
    return self.m_sAnswer
end

function CQuestion:GetTime()
    return self.m_iTime
end

function CQuestion:SetAnswererTime()
    self:Dirty()
    self.m_iAnswerTime = get_time()
end

function CQuestion:GetAnswerTime()
    return self.m_iAnswerTime
end

function CQuestion:GetContext()
    return self.m_sContext
end

function CQuestion:Save()
    local mData = {}
    mData.id = self.m_iId
    mData.pid = self.m_iOwnerPid
    mData.time = self.m_iTime
    mData.type = self.m_iType
    mData.context = self.m_sContext
    mData.qq_no = self.m_sQQ_No
    mData.phone_no = self.m_sPhone_No
    mData.picture_urls = self.m_mUrl
    mData.state = self.m_iState
    mData.playerinfo = self.m_mPlayerInfo
    mData.answer = self.m_sAnswer
    mData.answer_time = self.m_iAnswerTime
    mData.answerer = self.m_sAnswerer
    return mData
end

function CQuestion:Load(mData)
    if not mData or not mData.info then return end
    mData = mData.info
    self.m_iId = mData.id
    self.m_iOwnerPid = mData.pid
    self.m_iTime = mData.time
    self.m_iType = mData.type
    self.m_sContext = mData.context
    self.m_sQQ_No = mData.qq_no
    self.m_sPhone_No = mData.phone_no
    self.m_mUrl = mData.picture_urls
    self.m_iState = mData.state
    self.m_mPlayerInfo = mData.playerinfo
    self.m_sAnswer = mData.answer
    self.m_iAnswerTime = mData.answer_time
    self.m_sAnswerer = mData.answerer
end

function CQuestion:PackNet()
    local mNet = {
        question_id = self.m_iId,
        question = self:GetContext(),
        question_time = self:GetTime(),
        answer = self:GetAnswer(),
        answer_time = self:GetAnswerTime(),
    }
    return mNet
end

function CQuestion:ConfigSaveFunc()
    local iPid = self.m_iOwnerPid
    local iQue = self.m_iId

    self:ApplySave(function()
        local oQuestion = global.oFeedBackMgr:GetQuestion(iPid, iQue)
        if oQuestion then
            oQuestion:SaveDb()
        end
    end)
end

function CQuestion:SaveDb()
    local mInfo = {}
    mInfo.module = "feedbackdb"
    mInfo.cmd = "SaveQuestion"
    mInfo.cond = {id = self.m_iId, pid = self.m_iOwnerPid}
    mInfo.data = self:Save()

    gamedb.SaveDb(self.m_iId, "common", "DbOperate", mInfo)
end
