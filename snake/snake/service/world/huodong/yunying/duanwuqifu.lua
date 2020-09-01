local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "端午祈福"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_iItemNum = 0         --上交祭品数量
    self.m_iStartTime = 0
    self.m_iEndTime = 0

    self.m_iRetNpcNum = 0       --场景剩余npc数量
end

function CHuodong:Save()
    local mData = {}
    mData.itemnum = self.m_iItemNum
    mData.starttime = self.m_iStartTime
    mData.endtime = self.m_iEndTime
    return mData
end

function CHuodong:Load(mData)
    if not mData then return end

    self.m_iItemNum = mData.itemnum
    self.m_iStartTime = mData.starttime
    self.m_iEndTime = mData.endtime
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:AfterLoad()
    self:CheckTimer()
end

function CHuodong:AddItemNum(iAdd, mExclude)
    self:Dirty()
    local iOld = self.m_iItemNum
    self.m_iItemNum = self.m_iItemNum + iAdd

    local mRewardStep = self:GetRewardStep()
    for i, mStep in ipairs(mRewardStep) do
        if iOld < mStep.total and self.m_iItemNum > mStep.total then
            local mNet = net.Mask("GS2CRefreshDuanwuQifu", {total=self.m_iItemNum})
            global.oNotifyMgr:WorldBroadcast("GS2CRefreshDuanwuQifu", mNet, mExclude)
        end
    end
end

function CHuodong:AddNpcNum(iAdd)
    self:Dirty()
    self.m_iRetNpcNum = self.m_iRetNpcNum + iAdd
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if self:InHuodongTime() then
        self:RefreshDuanquQifu(oPlayer)
    end
end

function CHuodong:NewHour(mNow)
    self:CheckTimer()
    self:RefreshNpc()
    self:TryStopRewardMonitor()

    if self:InHuodongTime() then
        self:TryStartRewardMonitor()
    end
end

function CHuodong:CheckTimer(bFirst)
    local iCurrTime = get_time()
    if iCurrTime >= self.m_iStartTime then
        if bFirst then
            self:GameStart()
        end
    else
        local iDelta = self.m_iStartTime - iCurrTime
        self:DelTimeCb("GameStart")
        self:AddTimeCb("GameStart", iDelta * 1000, function()
            self:GameStart()
        end)
    end
    if iCurrTime >= self.m_iEndTime then
        if bFirst then
            self:GameOver()
        end
    else
        local iDelta = self.m_iEndTime - iCurrTime
        self:DelTimeCb("GameOver")
        self:AddTimeCb("GameOver", iDelta * 1000, function()
            self:GameOver()
        end)
    end
end

function CHuodong:GameStart()
    self:TryStartRewardMonitor()
    self:RefreshNpc()
    global.oNotifyMgr:WorldBroadcast("GS2CDuanwuQifuState", {open=1})
end

function CHuodong:GameOver()
    self:DelTimeCb("DuanwuQifuAnnounce")
    self:TryStopRewardMonitor()
    self:RemoveTempNpcByType(1001)
    global.oNotifyMgr:WorldBroadcast("GS2CDuanwuQifuState", {open=0})

    self:Dirty()
    self:Init()
end

function CHuodong:InHuodongTime()
    local iTime = get_time()
    return iTime >= self.m_iStartTime and iTime < self.m_iEndTime
end

function CHuodong:RegisterHD(mInfo, bClose)
    if not global.oToolMgr:IsSysOpen("DUANWUQIFU") then
        return false, "system is close"
    end

    if bClose then
        self:GameOver()
    else
        if self:InHuodongTime() then
            return false, self.m_sTempName .. "has started"
        end
        local iStartTime = mInfo.start_time
        local iEndTime = mInfo.end_time
        assert(iStartTime < iEndTime)

        self:SetGameTime(iStartTime, iEndTime)
    end
    return true
end

function CHuodong:SetGameTime(iStartTime, iEndTime)
    self.m_iStartTime = iStartTime
    self.m_iEndTime = iEndTime
    self:Dirty()
    self:CheckTimer(true)

    record.info("set huodong time start:" .. get_format_time(iStartTime) .. ",end:" .. get_format_time(iEndTime))
end

function CHuodong:RefreshNpc()
    self:DelTimeCb("DuanwuQifuAnnounce")
    if not self:InHuodongTime() then return end

    local mConfig = self:GetConfig()
    local iHour = get_timetbl().date.hour
    if iHour < mConfig.start_hour or iHour > mConfig.end_hour then
        return
    end

    if iHour + 1 <= mConfig.end_hour then
        self:AddTimeCb("DuanwuQifuAnnounce", 50*60*1000, function()
            self:SysAnnounce(1122)
        end)
    end

    local iTotal = self.m_iTestNum or table_count(global.oWorldMgr:GetOnlinePlayerList())
    iTotal = formula_string(mConfig.refresh_num, {total = iTotal})
    local iAddNum = iTotal - self.m_iRetNpcNum
    if iAddNum <= 0 then return end

    local lRefreshNum = {}
    for i = 1, math.floor(iAddNum/100) do
        table.insert(lRefreshNum, 100)
    end
    table.insert(lRefreshNum, iAddNum%100)

    self:SysAnnounce(1123)

    global.oToolMgr:ExecuteList(lRefreshNum, 1, 500, 0, "DuanwuQifuRefresh", function(iNum)
        self:TrueRefreshNpc(1001, iNum)
    end)
end

function CHuodong:TrueRefreshNpc(iNpcIdx, iAddNum)
    self:AddNpcNum(iAddNum)
    for i = 1, iAddNum do
        local oNpc = self:CreateTempNpc(iNpcIdx)
        local iX, iY = global.oSceneMgr:RandomPos2(oNpc:MapId())
        oNpc.m_mPosInfo.x = iX
        oNpc.m_mPosInfo.y = iY
        self:Npc_Enter_Map(oNpc)
    end
end

function CHuodong:PacketNpcInfo(iTempNpc, oPlayer)
    local mArgs = super(CHuodong).PacketNpcInfo(self, iTempNpc, oPlayer)
    if iTempNpc == 1001 then
        local mConfig = self:GetConfig()
        local lSceneList = mConfig.scene_list
        mArgs.map_id = lSceneList[math.random(1, #lSceneList)]
    end
    return mArgs
end

function CHuodong:RemoveTempNpc(oNpc)
    if oNpc and oNpc:Type() == 1001 then
        self:AddNpcNum(-1)
    end
    super(CHuodong).RemoveTempNpc(self, oNpc)
end

function CHuodong:OtherScript(iPid, npcobj, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if s == "$click" then
        if self:ValidClick(oPlayer, npcobj) then
            self:Click(oPlayer, npcobj)
            return true
        end
    else
        return super(CHuodong).OtherScript(self, iPid, npcobj, s, mArgs)
    end
end

function CHuodong:ValidClick(oPlayer, npcobj)
    if not global.oToolMgr:IsSysOpen("DUANWUQIFU", oPlayer) then
        return false
    end
    local iPid = oPlayer:GetPid()
    if not self:InHuodongTime() then
        self:Notify(iPid, 1003)
        return false
    end
    local mConfig = self:GetConfig()
    if oPlayer.m_oTodayMorning:Query("duanwuqifu_day_limit", 0) >= mConfig.day_limit then
        self:Notify(iPid, 1002)
        return false
    end
    if oPlayer.m_oThisTemp:Query("duanwuqifu_hour_limit", 0) >= mConfig.hour_limit then
        self:Notify(iPid, 1001)
        return false
    end
    return true
end

function CHuodong:Click(oPlayer, oNpc)
    local iEnd = get_hourtime({}).time
    local iCnt = oPlayer.m_oThisTemp:Query("duanwuqifu_hour_limit", 0)
    iCnt = iCnt + 1
    oPlayer.m_oThisTemp:Reset("duanwuqifu_hour_limit", iCnt, math.max(1, iEnd-get_time()))
    oPlayer.m_oTodayMorning:Add("duanwuqifu_day_limit", 1)
    self:RemoveTempNpc(oNpc)
    self:Reward(oPlayer:GetPid(), 1001)

    local mLogData = oPlayer:LogData()
    mLogData.action = "click"
    record.log_db("huodong", "duanwuqifu", {info=mLogData})
end

function CHuodong:SubmitItem(oPlayer)
    if not global.oToolMgr:IsSysOpen("DUANWUQIFU", oPlayer) then
        return
    end
    local iPid = oPlayer:GetPid()
    if not self:InHuodongTime() then
        self:Notify(iPid, 1003)
        return
    end
    local mConfig = self:GetConfig()
    local iSid = mConfig.submit_sid
    local iHasAmount = oPlayer:GetItemAmount(iSid)
    if iHasAmount <= 0 then
        self:Notify(iPid, 1004)
        return
    end

    local sReason = "上交祭品"
    oPlayer:RemoveItemAmount(iSid, iHasAmount, sReason)
    self:AddItemNum(iHasAmount, {[iPid] = 1})
    self:RefreshDuanquQifu(oPlayer)
    self:Reward(iPid, mConfig.submit_reward, {argenv={amount=iHasAmount}})

    local mLogData = oPlayer:LogData()
    mLogData.action = "submit"
    mLogData.amount = iHasAmount
    record.log_db("huodong", "duanwuqifu", {info=mLogData})


    if math.random(100) <= mConfig.ratio then
        local oHuodong = global.oHuodongMgr:GetHuodong("zongzigame")
        if oHuodong and oHuodong:InHuodongTime() then
            oHuodong:TryAddExchange(oPlayer, 1, "qifu")
        end
    end
end

function CHuodong:StepReward(oPlayer, iStep)
     if not global.oToolMgr:IsSysOpen("DUANWUQIFU", oPlayer) then
        return
    end
    local iPid = oPlayer:GetPid()
    if not self:InHuodongTime() then
        self:Notify(iPid, 1003)
        return
    end
    local mRewardStep = self:GetRewardStep()
    if not mRewardStep[iStep] then
        self:Notify(iPid, 1005)
        return
    end
    local mStep = mRewardStep[iStep]
    if oPlayer:Query(mStep.reward_key, 0) > 0 then
        self:Notify(iPid, 1006)
        return
    end
    if self.m_iItemNum < mStep.total then
        self:Notify(iPid, 1007)
        return
    end

    oPlayer:Add(mStep.reward_key, 1)
    self:Reward(iPid, mStep.reward)
    self:RefreshDuanquQifu(oPlayer)

    local mLogData = oPlayer:LogData()
    mLogData.action = "reward"
    mLogData.step = iStep
    record.log_db("huodong", "duanwuqifu", {info=mLogData})
end

function CHuodong:PackDuanwuQifu(oPlayer)
    local mNet = {
        starttime = self.m_iStartTime,
        endtime = self.m_iEndTime,
        total = self.m_iItemNum,
    }
    local lRewardStep = {}
    local mRewardStep = self:GetRewardStep()
    for i, mInfo in ipairs(mRewardStep) do
        table.insert(lRewardStep, oPlayer:Query(mInfo.reward_key, 0))
    end
    mNet.reward_step = lRewardStep
    return mNet
end

function CHuodong:RefreshDuanquQifu(oPlayer)
    local mNet = self:PackDuanwuQifu(oPlayer)
    mNet = net.Mask("GS2CRefreshDuanwuQifu", mNet)
    oPlayer:Send("GS2CRefreshDuanwuQifu", mNet)
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["duanwuqifu"]["config"][1]
end

function CHuodong:GetRewardStep()
    return res["daobiao"]["huodong"]["duanwuqifu"]["reward_step"]
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 开游戏
        102 - 关游戏
        103 - 清理领取标记
        104 - 刷新祭品 {100}
        105 - 清理获取祭品标记(小时)
        106 - 清理获取祭品标记(天)
        ]])
    elseif iFlag == 101 then
        self:SetGameTime(get_time(), get_time() + 3600)
    elseif iFlag == 102 then
        self:GameOver()
    elseif iFlag == 103 then
        local mRewardStep = self:GetRewardStep()
        for i, mInfo in ipairs(mRewardStep) do
            oMaster:Set(mInfo.reward_key, nil)
        end
        self:RefreshDuanquQifu(oMaster)
    elseif iFlag == 104 then
        self.m_iTestNum = (mArgs[1] and mArgs[1] > 0) and mArgs[1] or nil
        self:RefreshNpc()
    elseif iFlag == 105 then
        oMaster.m_oThisTemp:Delete("duanwuqifu_hour_limit")
    elseif iFlag == 106 then
        oMaster.m_oTodayMorning:Set("duanwuqifu_day_limit", nil)
    elseif iFlag == 107 then
        self:SubmitItem(oMaster)
    elseif iFlag == 108 then
        self:StepReward(oMaster, mArgs[1])
    end
end
