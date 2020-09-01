--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "跳舞"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    self.m_sName = sHuodongName
    o.m_iScheduleID = 1016
    return o
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    self:GS2CDanceLeftCnt(oPlayer)
end

function CHuodong:NewDay(mNow)
    local oWorldMgr = global.oWorldMgr
    for pid,oPlayer in pairs(oWorldMgr.m_mOnlinePlayers) do
        self:GS2CDanceLeftCnt(oPlayer)
    end
end

function CHuodong:CheckStartDance(oPlayer, iFlag)
    local oNotifyMgr = global.oNotifyMgr
    local mRes=res["daobiao"]["huodong"]["dance"]["condition"][1]
    local oSceneMgr = global.oSceneMgr
    local iScene = oPlayer.m_oActiveCtrl:GetNowScene():GetSceneId()
    local mPos = oPlayer:GetNowPos()
    if not global.oToolMgr:IsSysOpen("DANCE_STAMPS",oPlayer) then
        return 
    end
    if  not oSceneMgr:IsInDance(iScene, mPos.x, mPos.y) then 
        oNotifyMgr:Notify(oPlayer:GetPid(),"不在活动范围")
        return 
    end
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("DANCE_STAMPS")
    if oPlayer:GetGrade() < iOpenGrade then 
        local sText = self:GetTextData(1001)
        sText = global.oToolMgr:FormatColorString(sText,{grade = iOpenGrade})
        oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        return 
    end
    local iActivePoint =  oPlayer.m_oScheduleCtrl:GetTotalPoint()
    if iActivePoint < mRes["active_point"] then
        local sText = self:GetTextData(1009)
        sText = global.oToolMgr:FormatColorString(sText,{point= mRes["active_point"]})
        oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        return
    end
    local oState = oPlayer.m_oStateCtrl:GetState(1002)
    if oState then
        oNotifyMgr:Notify(oPlayer:GetPid(), "你正在跳舞中，请稍后再操作")
        return
    end
    if oPlayer.m_oTodayMorning:Query("dance",0) >= mRes["limitcnt"] then 
        oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1003))
        return 
    end
    -- if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
    --     oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1004))
    --     return
    -- end
    local mCost = mRes["cost"]
    local sid, iCostAmount = mCost["itemid"], mCost["amount"]
    local iHaveAmount = oPlayer.m_oItemCtrl:GetItemAmount(sid)
    if iFlag and iFlag > 0 then
        local sReason = "快捷开始跳舞"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        mNeedCost["item"][sid] = iCostAmount
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
    else
        if iHaveAmount < iCostAmount then 
            oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1002))
            return 
        end
        if not oPlayer:RemoveItemAmount(sid,iCostAmount, "开始跳舞",{cancel_tip = true}) then 
            oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1002))
            return 
        end
    end
    self:Dance(oPlayer)
    oPlayer:MarkGrow(46)
end

function CHuodong:Dance(oPlayer)
    oPlayer.m_oTodayMorning:Add("dance",1)
    local oState = oPlayer.m_oStateCtrl:GetState(1002)
    assert(not oState,"dance repeated")
    local iTime = res["daobiao"]["huodong"]["dance"]["condition"][1]["len"]
    assert(iTime>0 ,string.format("dance time error %s",iTime))
    oPlayer.m_oStateCtrl:AddState(1002,{time=iTime})
    self:GS2CDanceLeftCnt(oPlayer)
    self:AddSchedule(oPlayer)

    local mLogData={
    pid = oPlayer:GetPid(),
    flag = "dance_time",
    op = "inc",
    value = oPlayer.m_oTodayMorning:Query("dance"),
    }
    record.log_db("huodong", "dance",mLogData)
end

function CHuodong:RewardExp(oPlayer, iExp,mArgs)
    if iExp <= 0 then return end
    local mNet = {}
    mNet.double = 0
    local iRatio = res["daobiao"]["huodong"]["dance"]["condition"][1]["reward_ratio"]
    if math.random(100)<iRatio then
        iExp = iExp*2 
        mNet.double =1
    end
    mArgs = mArgs or {}
    mArgs.bEffect = true
    mArgs.cancel_tip = true
    mArgs.cancel_chat = true
    local mResult = oPlayer:RewardExp(iExp, self.m_sName,mArgs)
    local sChatMsg
    if mResult.chubei_exp >0 then
        local sText = self:GetTextData(1005)
        sChatMsg = global.oToolMgr:FormatColorString(sText, {exp = {mResult.exp+mResult.chubei_exp, mResult.chubei_exp}})
    else
        local sText = self:GetTextData(1006)
        sChatMsg = global.oToolMgr:FormatColorString(sText, {exp = {mResult.exp}})
    end
    if sChatMsg then
        global.oChatMgr:HandleMsgChat(oPlayer, sChatMsg)
    end
    mNet.exp = mResult.exp+mResult.chubei_exp
    oPlayer:Send("GS2CDanceDoubleReward",mNet)
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    mArgs = mArgs or {}
    mArgs.cancel_tip = true
    mArgs.cancel_chat = true
    for itemidx, mItems in pairs(mAllItems) do
        local lItems = mItems["items"]
        for _, oItem in ipairs(lItems) do
            local sText
            if oItem:SID() == 1002 then
                sText = self:GetTextData(1008)
                sText = global.oToolMgr:FormatColorString(sText, {silver = oItem:GetData("Value",0)})
            else
                sText = self:GetTextData(1007)
                sText = global.oToolMgr:FormatColorString(sText, {amount = oItem:GetAmount(),item=oItem:TipsName()})
            end
            if sText then
                if not oPlayer:InWar() then
                    global.oNotifyMgr:Notify(oPlayer:GetPid(),sText)
                end
                global.oChatMgr:HandleMsgChat(oPlayer, sText)
            end
        end
    end
    super(CHuodong).RewardItems(self, oPlayer, mAllItems, mArgs)
end

function CHuodong:GS2CDanceLeftCnt(oPlayer)
    local mNet = {}
    local iCnt = oPlayer.m_oTodayMorning:Query("dance",0)
    local mRes=res["daobiao"]["huodong"]["dance"]["condition"][1]
    mNet["leftcnt"] = math.max(0, mRes["limitcnt"] - iCnt)
    oPlayer:Send("GS2CDanceLeftCnt", mNet)
end

function CHuodong:AutoFindDanceArea(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oPlayer:IsSingle() and not oPlayer:IsTeamLeader() then
        oNotifyMgr:Notify(pid,self:GetTextData(1004))
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    local iMapID,x,y = global.oSceneMgr:RandomDance()
    x = 32
    y = 30
    global.oSceneMgr:SceneAutoFindPath(pid,iMapID,x,y,nil,1)
end

function CHuodong:GetRewardEnv(oAwardee)
    local mEnv = super(CHuodong).GetRewardEnv(self, oAwardee)
    mEnv.team = 1
    if oAwardee.HasTeam and oAwardee:HasTeam() then
        local oTeam = oAwardee:HasTeam()
        mEnv.team = oTeam:TeamSize()
    end
    return mEnv
end

function CHuodong:TestOp(iFlag, arg)
    local oNotifyMgr = global.oNotifyMgr
    local pid = arg[#arg]
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag ==101 then
        self:CheckStartDance(oPlayer)
    elseif iFlag == 102 then
        oPlayer.m_oTodayMorning:Delete("dance")
        self:GS2CDanceLeftCnt(oPlayer)
    elseif iFlag == 103 then
        self:Reward(pid,1001)
    end
    oNotifyMgr:Notify(oPlayer:GetPid(),"执行完毕")
end
