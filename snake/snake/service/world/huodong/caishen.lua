local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local serverinfo = import(lualib_path("public.serverinfo"))
local rewardmonitor = import(service_path("rewardmonitor"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "财神送礼"
inherit(CHuodong, huodongbase.CHuodong)

local GAME_CLOSE = 0
local GAME_OPEN = 1
local GAME_READY_OPEN = 2

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.start_time = self.m_iStartTime
    mData.end_time = self.m_iEndTime
    mData.hd_id = self.m_iHDID
    mData.hd_key = self.m_sHD2RewardGroupKey
    mData.status = self.m_iStatus
    mData.merge_server = self.m_iMergeServer
    mData.merge_version = self.m_iMergeVersion
    mData.record_list = table_to_db_key(self:PackRewardRecordInfo(0) or {})
    mData.record_lasttime = self.m_mRewardRecord.iRecordCurTime
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iStartTime = mData.start_time or 0
    self.m_iEndTime = mData.end_time or 0
    self.m_iHDID = mData.hd_id or 0
    self.m_sHD2RewardGroupKey = mData.hd_key
    self.m_iStatus = mData.status or 0
    self.m_iMergeServer = mData.merge_server or 0
    self.m_iMergeVersion = mData.merge_version or 0
    if self.m_mRewardRecord then
        self.m_mRewardRecord.lRecord = {}
        local iCurTime = get_time()
        for _,mRecord in pairs(mData.record_list or {}) do
            local mInsertRecord = {
                sName = mRecord.name,
                iMultiple = mRecord.multiple,
                iTimestamp = iCurTime,
            }
            table.insert(self.m_mRewardRecord.lRecord,mInsertRecord)
        end
        self.m_mRewardRecord.iRecordCurTime = iCurTime
    end
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong caishen without data"
    end
    self.m_iMergeVersion = math.max(self.m_iMergeVersion, mFromData.merge_version or 0)
    if self.m_iStatus == GAME_OPEN and mFromData.status == GAME_OPEN then
        self.m_iMergeServer = 1
        self.m_iMergeVersion = self.m_iMergeVersion + 1
    end
    self:Dirty()
    return true
end

function CHuodong:GameEnd()
    self.m_iStatus = GAME_CLOSE
    self.m_iMergeServer = 0
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self:TryStopRewardMonitor()
    local lAllOnlinePid = {}
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        table.insert(lAllOnlinePid,oPlayer:GetPid())
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid,100,1000,0,"CaishenGameEnd",function (pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        local mNet = {
            group_key = self:GetHD2RewardGroupKey(),
            start_time = self.m_iStartTime,
            end_time = self.m_iEndTime,
            status = self.m_iStatus,
            reward_key = self:GetRewardKey(oPlayer),
            reward_surplus = self:GetRewardSurplus(oPlayer),
        }
        oPlayer:Send("GS2CCaishenRefreshRewardKey",mNet)
        end)
    record.info("huodong caishen end %d,%s",self.m_iHDID,self.m_sHD2RewardGroupKey)
end

function CHuodong:GameStart()
    -- 广播给玩家
    self.m_iStatus = GAME_OPEN
    self:Dirty()
    self:TryStartRewardMonitor()
    local lAllOnlinePid = {}
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        table.insert(lAllOnlinePid,oPlayer:GetPid())
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid,100,1000,0,"CaishenGameStart",function (pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        local mNet = {
            group_key = self:GetHD2RewardGroupKey(),
            start_time = self.m_iStartTime,
            end_time = self.m_iEndTime,
            status = self.m_iStatus,
            reward_key = self:GetRewardKey(oPlayer),
            reward_surplus = self:GetRewardSurplus(oPlayer),
        }
        oPlayer:Send("GS2CCaishenRefreshRewardKey",mNet)
        end)
    global.oHotTopicMgr:Register(self.m_sName)
    record.info("huodong caishen start %d,%s",self.m_iHDID,self.m_sHD2RewardGroupKey)
end

function CHuodong:CheckRegisterInfo(mInfo)
    if self.m_sName ~= mInfo["hd_type"] then 
        return false, " no hd_type" .. mInfo["hd_type"]
     end
    local sHDKey = mInfo["hd_key"]
    if not sHDKey then 
        return false,"no huodong key" .. mInfo["hd_key"]
    end
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][sHDKey]
    if not mConfig then 
        return false ,"no huodong config"
    end
    if not mInfo["end_time"] or mInfo["end_time"] <= get_time()then
        return false,"end_time over"
    end
    if not mInfo["start_time"] or mInfo["start_time"] > mInfo["end_time"] then
        return false,"start_time error"
    end
    return true
end

function CHuodong:TryGameStart(mInfo)
        if  mInfo["hd_id"] ~= self.m_iHDID then
            self.m_iHDID = mInfo["hd_id"]
            self.m_sHD2RewardGroupKey = mInfo["hd_key"]
            self.m_mRewardRecord.lRecord = {}
            self.m_mRewardRecord.iRecordCurTime = 0
        end
        self.m_iStartTime = mInfo["start_time"]
        self.m_iEndTime = mInfo["end_time"]
        self.m_iStatus = GAME_READY_OPEN
        self:Dirty()

        if self.m_iStartTime <= get_time() then         
            self:GameStart()
        elseif self.m_iStartTime - get_time() <= 3600 then      
            self:DelTimeCb("GameTimeStart")
            self:AddTimeCb("GameTimeStart",(self.m_iStartTime- get_time()) * 1000,function ()
            self:DelTimeCb("GameTimeStart")
            if self.m_iStatus ~= GAME_READY_OPEN then return end
            self:GameStart()
             end)
        end
end

function CHuodong:TryGameEnd()
    self:GameEnd()
end

function CHuodong:RegisterHD(mInfo,bClose)
    if bClose then
        self:TryGameEnd()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then return false, sError end
        self:TryGameStart(mInfo)
    end
    return true
end

function CHuodong:Init()
    self.m_iStatus = GAME_CLOSE
    self.m_mRewardRecord = {}
    self.m_mRewardRecord.lRecord = {}
    self.m_mRewardRecord.iRecordMaxsize = 15
    self.m_mRewardRecord.iRecordCurTime = 0
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self.m_iStatus == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime  <= 3600 then
            self:DelTimeCb("GameTimeStart")
            self:AddTimeCb("GameTimeStart", (self.m_iStartTime - iTime) * 1000, function ()
                self:DelTimeCb("GameTimeStart")
                if self.m_iStatus ~= GAME_READY_OPEN then return end
                self:GameStart()
            end)
        end
    elseif self.m_iStatus == GAME_OPEN then
        if self.m_iEndTime <= iTime then
            self:TryGameEnd()
        elseif self.m_iEndTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeEnd")
            self:AddTimeCb("GameTimeEnd",(self.m_iEndTime - iTime)*1000,function()
                self:DelTimeCb("GameTimeEnd")
                if self.m_iStatus ~= GAME_OPEN then return end
                self:TryGameEnd() 
                end)
        end
    end
end

-- 不能放在onlineoffset, 此时已经被当做新活动重置了
function CHuodong:MergeServer(oPlayer)
    if self.m_iMergeServer == 1 and oPlayer:Query("caishen_merge_version", 0) < self.m_iMergeVersion then
        oPlayer:Set("caishen_merge_version", self.m_iMergeVersion)
        local sKey = self:GetSaveKey()
        local mSaveInfo = oPlayer:Query(sKey, {})
        mSaveInfo.hd_id = self:GetHDID()
        mSaveInfo.reward_key = mSaveInfo.reward_key or 0
        oPlayer:Set(sKey, mSaveInfo)
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:MergeServer(oPlayer)
    local mNet = {
        group_key = self:GetHD2RewardGroupKey(),
        reward_key = self:GetRewardKey(oPlayer),
        reward_surplus = self:GetRewardSurplus(oPlayer),
        start_time = self.m_iStartTime,
        end_time = self.m_iEndTime,
        status = self.m_iStatus,
    }
    oPlayer:Send("GS2CCaishenRefreshRewardKey", mNet)
end

function CHuodong:InsertRewardRecord(mData)
    local mRecord = self.m_mRewardRecord
    if #mRecord >= mRecord.iRecordMaxsize then
        table.remove(mRecord.lRecord,1)
    end
    table.insert(mRecord.lRecord,mData)
    mRecord.iRecordCurTime = mData.iTimestamp
end

function CHuodong:C2GSRefreshRewardRecord(oPlayer,iTime)
    self:_RefreshRewardRecord(oPlayer,iTime)
end

function CHuodong:_RefreshRewardRecord(oPlayer,iTime)
    local mNet = { }
    mNet.record_list =  self:PackRewardRecordInfo(iTime)
    mNet.last_time = self.m_mRewardRecord.iRecordCurTime
    oPlayer:Send("GS2CCaishenRefreshRewardRecord",mNet)
end

function CHuodong:PackRewardRecordInfo(iTime)
    local lRecordNet = {}
    for _,mRecord in ipairs(self.m_mRewardRecord.lRecord) do
        if mRecord.iTimestamp > iTime then
            local mOneRecord = {
                name = mRecord.sName,
                multiple = mRecord.iMultiple,
            }
            table.insert(lRecordNet,mOneRecord)
        end
    end
    if #lRecordNet == 0 then
        return nil
    else
        return lRecordNet
    end
end

function CHuodong:C2GSTryOpenCaishenUI(oPlayer,iTime)
   local mNet = {
        group_key = self:GetHD2RewardGroupKey(),
        reward_key = self:GetRewardKey(oPlayer) ,
        reward_surplus = self:GetRewardSurplus(oPlayer),
        start_time = self.m_iStartTime,
        end_time = self.m_iEndTime,
        status = self.m_iStatus,
    }
    oPlayer:Send("GS2CCaishenRefreshRewardKey", mNet)
    self:_RefreshRewardRecord(oPlayer,iTime)
end

function CHuodong:TryStartRewardMonitor()
    if not self.m_oRewardMonitor then
        local lUrl = {"huodong","caishen"}
        local o = rewardmonitor.NewMonitor(self.m_sName,lUrl)
        self.m_oRewardMonitor = o
    end
end

function CHuodong:TryStopRewardMonitor()
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
end

function CHuodong:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(iPid, iRewardId, iCnt, mArgs) then
            return false
        end
    end
    return true
end

function CHuodong:ValidStartChoose(oPlayer, iKey)
    if self.m_iStatus  == 0 then
        return 1001
    end

    if not global.oToolMgr:IsSysOpen("CAISHEN", oPlayer) then
        return 1001
    end

    local mConfig  = self:GetConfig()
    if not mConfig then return 1001 end

    local mCost = self:GetCostConfig()
    if not mCost[iKey] then return 1004 end

    if self:GetRewardKey(oPlayer) ~= mCost[iKey].pre_key then
        return 1004
    end

    if oPlayer.m_iCaishen then
        return 1005
    end

    return 1
end

function CHuodong:C2GSCaishenStartChoose(oPlayer, mData)
    local iKey = mData.reward_key or 1
    local iRet = self:ValidStartChoose(oPlayer, iKey)
    if iRet ~= 1 then
        if iRet ~= 1001 then
            self:Notify(oPlayer:GetPid(), iRet)
        end
        return
    end
    local mCost = self:GetCostConfig()[iKey]
    local oProfile = oPlayer:GetProfile()
    if oProfile:TrueGoldCoin() < mCost.goldcoin then
        self:Notify(oPlayer:GetPid(), 1006)
        return
    end

    if not self:CheckRewardMonitor(oPlayer:GetPid(),mCost["lottery_id"],1) then
        return
    end

    local iPid = oPlayer:GetPid()
    oPlayer.m_iCaishen = 1
    self:SetRewardKey(oPlayer,iKey)
    oProfile:ResumeTrueGoldCoin(mCost.goldcoin, "财神送礼", {cancel_rank=1})

    local func = function(oPlayer, mItems, sReason)
        self:DoRewardCaishen(oPlayer, mItems, iKey, sReason)
    end

    local cbfunc = function(oPlayer, mItems)
        self:TryStopCaishenChoose(oPlayer, mItems, iKey)
        local iLastRecordTime = self.m_mRewardRecord.iRecordCurTime
        local iCurTime = get_time()
        local iTempMultiple = tonumber(mItems["info"]["multiple"])
        if iTempMultiple and iTempMultiple >= 2 then
            local mData = {
                sName = oPlayer:GetName(),
                iMultiple = iTempMultiple * 1000 ,
                iTimestamp = iCurTime,
            }
            self:InsertRewardRecord(mData)
            self:_RefreshRewardRecord(oPlayer,iLastRecordTime)
        end
    end
    global.oLotteryMgr:Lottery(oPlayer, mCost.lottery_id, func, cbfunc)

    local mLog = {
        hd_id = self.m_iHDID,
        group_key = self:GetHD2RewardGroupKey(),
        reward_key = iKey,
        cost = mCost.goldcoin,
    }
    record.log_db("huodong", "caishen", {pid=iPid, info=mLog})
end

function CHuodong:DoRewardCaishen(oPlayer, mItems, iKey, sReason)
    oPlayer:SetLogoutJudgeTime()
    oPlayer:DelTimeCb("TryStopLottery")
   
    local oProfile = oPlayer:GetProfile()
    local mCost = self:GetCostConfig()[iKey]
    local iCostGoldCoin = mCost.goldcoin
    local sTip = string.format("获得%s#cur_1", iCostGoldCoin)

    for _, oItem in pairs(mItems["items"]) do
        local iSid = oItem:SID()
        if iSid == 1003 then
            local sReason = "财神送礼返回"
            local iValue = oItem:GetData("Value")
            local iRplGoldCoin = math.max(0, iValue - iCostGoldCoin)
            oProfile:AddGoldCoin(iCostGoldCoin, sReason, {cancel_tip=true})
            if iRplGoldCoin > 0 then
                sTip = sTip .. string.format("%s#cur_2", iRplGoldCoin)
                oProfile:AddRplGoldCoin(iRplGoldCoin, sReason, {cancel_tip=true})
            end
            oPlayer:NotifyMessage(sTip)
            baseobj_delay_release(oItem)
        end
    end
    local iSys = mItems["info"]["sys"]
    local mChuanwen = res["daobiao"]["chuanwen"][iSys]
    if mChuanwen then
        local sMsg, iHorse = mChuanwen.content, mChuanwen.horse_race
        local sMsg = global.oToolMgr:FormatColorString(sMsg, {role=oPlayer:GetName(),multiple = mItems["info"]["multiple"]})
        global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
    end
end

function CHuodong:TryStopCaishenChoose(oPlayer, mItems, iKey)
    oPlayer.m_iCaishen = nil
   local mNet = {
        group_key = self:GetHD2RewardGroupKey(),
        reward_key = self:GetRewardKey(oPlayer) ,
        reward_surplus = self:GetRewardSurplus(oPlayer),
        start_time = self.m_iStartTime,
        end_time = self.m_iEndTime,
        status = self.m_iStatus,
    }
    oPlayer:Send("GS2CCaishenRefreshRewardKey", mNet)

    local mLog = {
        hd_id = self:GetHDID(),
        group_key = self:GetHD2RewardGroupKey(),
        reward_key = iKey,
        reward_gold_coin = table_get_depth(mItems, {"info", "amount"})
    }
    record.log_db("huodong", "caishen", {pid=oPlayer:GetPid(), info=mLog})
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:GetChuanwen(iText)
    local mInfo = res["daobiao"]["chuanwen"][iText]
    return mInfo.content, mInfo.horse_race
end

function CHuodong:GetHDID()
    return self.m_iHDID
end

-- 用于玩家数据存储
function CHuodong:GetSaveKey()
    return self.m_sName
end

function CHuodong:GetHD2RewardGroupKey()
    return self.m_sHD2RewardGroupKey
end

-- GetRewardVal 和 SetRewardVal 将会使用判断是否是新的活动
function CHuodong:IsNewHD(oPlayer)
    local mSaveInfo = oPlayer:Query(self:GetSaveKey(),nil)
    local iCurHDID = self:GetHDID()
    if not mSaveInfo then
        mSaveInfo = {}
        mSaveInfo.hd_id = iCurHDID
        mSaveInfo.reward_key = 0
        oPlayer:Set(self:GetSaveKey(),mSaveInfo)
    -- 这里合服后会出现问题，被判断为新活动
    elseif mSaveInfo.hd_id ~= iCurHDID then
        mSaveInfo.hd_id = iCurHDID
        mSaveInfo.reward_key = 0
        oPlayer:Set(self:GetSaveKey(),mSaveInfo)
    end
end

function CHuodong:GetRewardKey(oPlayer)
    self:IsNewHD(oPlayer)
    local mRewardInfo = oPlayer:Query(self:GetSaveKey())
    return mRewardInfo.reward_key
end

function CHuodong:SetRewardKey(oPlayer,iKey)
    self:IsNewHD(oPlayer)
    local mSaveInfo = oPlayer:Query(self:GetSaveKey())
    mSaveInfo.reward_key = iKey
    oPlayer:Set(self:GetSaveKey(),mSaveInfo)
end

function CHuodong:GetConfig()
    local sGroupKey = self:GetHD2RewardGroupKey()
    return res["daobiao"]["huodong"][self.m_sName]["config"][sGroupKey]
end

function CHuodong:GetCostConfig()
    local sGroupKey = self:GetHD2RewardGroupKey()
    if sGroupKey then 
        return res["daobiao"]["huodong"][self.m_sName]["cost"][sGroupKey]["cost_list"]
    else
        return nil
    end
end

function CHuodong:GetRewardSurplus(oPlayer)
    local sGroupKey = self:GetHD2RewardGroupKey()
    if sGroupKey then 
        local iTotal = res["daobiao"]["huodong"][self.m_sName]["cost"][sGroupKey]["cost_size"]
        return math.max(iTotal - self:GetRewardKey(oPlayer), 0)
    else
        return 0
    end
end

function CHuodong:IsHuodongOpen()
    if self.m_iStatus == GAME_OPEN then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
101 - 模拟领取
102 - 清空玩家领取数据(具有领取监控，最多一个活动领取两次，即使再多次清空也无用)
103 - 玩家重新登录
104 - 运营开启活动 (ex -- 105 {hd_key = "caishen_reward_2"})(不填写参数，默认为 caishen_reward_1)
105 - 运营关闭活动
106 - 活动id
107 - 查询活动时间
        ]])
    elseif iFlag == 101 then
        local iKey = self:GetRewardKey(oMaster) + 1
        self:C2GSCaishenStartChoose(oMaster, {group_key = self:GetHD2RewardGroupKey(),reward_key=iKey})
    elseif iFlag == 102 then
        oMaster:Set(self:GetSaveKey(), nil)
    elseif iFlag == 103 then
        self:OnLogin(oMaster)
    elseif iFlag == 104 then
        local iStartTime = get_time()
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        local mInfo = {
            hd_id = self.m_iHDID + 1,
            hd_type = "caishen",
            hd_key = "caishen_reward_1",
            start_time = iStartTime + 30,
            end_time = iStartTime + 2*60*60,
        }
        if mArgs and mArgs.hd_key then
            mInfo.hd_key = mArgs.hd_key
        end
        local bClose = false
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        self:RegisterHD(mInfo,bClose)
    elseif iFlag == 105 then
        local mInfo = {
            hd_type = "caishen" ,
        }
        local bClose = true
        self:RegisterHD(mInfo,bClose)
    elseif iFlag == 106 then
        global.oChatMgr:HandleMsgChat(oMaster, "财神送礼活动ID" .. self.m_iHDID)
    elseif iFlag == 107 then
        local sMsg = os.date("%x %X",self.m_iStartTime) .. " --> " .. os.date("%x %X",self.m_iEndTime)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end
