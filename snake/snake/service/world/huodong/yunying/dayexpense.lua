local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日累消"
inherit(CHuodong, huodongbase.CHuodong)

local STATE_UNREACH = 0  -- 未达到
local STATE_REWARD = 1  -- 可领取
local STATE_REWARDED = 2 -- 已领取

local GAME_CLOSE = 0
local GAME_OPEN = 1
local GAME_READY_OPEN = 2  -- 活动准备开放，但是时间未到

function CHuodong:RegisterHD(mInfo,bClose)
    if bClose then
        self:TryGameClose()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then
            return false,sError
        end
        self:TryGameOpen(mInfo)
    end
    return true
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.hd_id = self.m_iHDID
    mData.hd_key = self.m_sHD2RewardGroupKey
    mData.start_time = self.m_iStartTime
    mData.end_time = self.m_iEndTime
    mData.state = self.m_iState
    local mSaveInfo = {}
    for pid, mPlayerReward in pairs(self.m_mRewardInfo) do
        mSaveInfo[db_key(pid)] = table_to_db_key(mPlayerReward)
    end
    mData.rewardinfo = mSaveInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iHDID = mData.hd_id or 0
    self.m_sHD2RewardGroupKey  = mData.hd_key
    self.m_iStartTime = mData.start_time or 0
    self.m_iEndTime = mData.end_time or 0
    self.m_iState = mData.state or GAME_CLOSE
    local mSaveInfo = {}
    for sPid,mPlayerReward in pairs(mData.rewardinfo or {}) do
        mSaveInfo[tonumber(sPid)] = table_to_int_key(mPlayerReward)
    end
    self.m_mRewardInfo = mSaveInfo
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong dayexpense without data"
    end
    if self.m_sHD2RewardGroupKey ~= mFromData.hd_key then return true end
    if self.m_iState == GAME_OPEN and mFromData.state == GAME_OPEN then
        for sPid, mPlayerReward in pairs(mFromData.rewardinfo or {}) do
            self.m_mRewardInfo[tonumber(sPid)] = table_to_int_key(mPlayerReward)
        end
        self:Dirty()
    end
    return true
end

function CHuodong:GetGameState()
    return self.m_iState
end

function CHuodong:CheckRegisterInfo(mInfo)
    if not global.oToolMgr:IsSysOpen("DAY_EXPENSE",nil,true) then
        return false, "system closed"
    end
    if mInfo["hd_type"] ~= self.m_sName then
        return false, "no hd_type" .. mInfo["hd_type"]
    end
    local sHDKey = mInfo["hd_key"]
    if not sHDKey then
        return  false, "no hd_key" .. mInfo["hd_key"]
    end
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][sHDKey]
    if not mConfig then 
        return  false,"no hd config"
    end
    if not mInfo["end_time"] or mInfo["end_time"] <= get_time() then
        return false,"end_time over"
    end
    if not mInfo["start_time"] or mInfo["start_time"] > mInfo["end_time"] then
        return false,"start_time error"
    end

    local mCloseDate = os.date("*t",mInfo["end_time"])
    if mCloseDate.hour > 5 then
        mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
    elseif mCloseDate.hour == 5  then
        if mCloseDate.min > 0 or mCloseDate.sec > 0 then
            mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
        end
    end
    mCloseDate = os.date("*t",mInfo["end_time"])
    mCloseDate.hour = 5
    mCloseDate.min = 0
    mCloseDate.sec = 0
    mInfo["end_time"] = os.time(mCloseDate)
    return true
end

function CHuodong:TryGameClose()
    self:GameEnd()
end

function CHuodong:TryGameOpen(mInfo)
    if mInfo["hd_id"] ~= self.m_iHDID then
        self.m_iHDID = mInfo["hd_id"]
        self.m_sHD2RewardGroupKey = mInfo["hd_key"]
        self.m_mRewardInfo = {}
    end
    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = GAME_READY_OPEN
    self:Dirty()

    local iNowTime = get_time()
    if self.m_iStartTime <= iNowTime then
        self:GameStart()
    elseif self.m_iStartTime - iNowTime < 3600 then
        self:DelTimeCb("GameTimeStart")
        self:AddTimeCb("GameTimeStart",(self.m_iStartTime - iNowTime) * 1000,function()
            self:DelTimeCb("GameTimeStart")
            if self.m_iState ~= GAME_READY_OPEN then return end
            self:GameStart()
        end)
    end
end

function CHuodong:GameStart()
    self.m_iState = GAME_OPEN
    self:Dirty()
    -- 广播 或 分片
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_group_key = self.m_sHD2RewardGroupKey
    record.log_db("huodong","dayexpense_state",mLogData)
    local lAllOnlinePid = {}
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        if global.oToolMgr:IsSysOpen("DAY_EXPENSE",oPlayer,true) then
            table.insert(lAllOnlinePid,oPlayer:GetPid())
        end
    end
    global.oToolMgr:ExecuteList(lAllOnlinePid,100,2*1000,0,"DayexpenseGameStart",function (pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:CheckReward(oPlayer)
        self:GS2CGameReward(oPlayer)
    end)
    global.oHotTopicMgr:Register(self.m_sName)
    record.info("huodong yunying dayexpense start %d,%s",self.m_iHDID,self.m_sHD2RewardGroupKey)
end

function CHuodong:GameEnd()
    self.m_iState = GAME_CLOSE
    global.oHotTopicMgr:UnRegister(self.m_sName)
    -- check 已经更新在线玩家状态
    self:CheckSendMailReward()
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_group_key = self.m_sHD2RewardGroupKey
    record.log_db("huodong","dayexpense_state",mLogData)
    record.info("huodong yunying dayexpense end %d,%s",self.m_iHDID,self.m_sHD2RewardGroupKey)
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    if self.m_iState == GAME_OPEN then
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("DAY_EXPENSE")
        if iFromGrade < iOpenGrade and iGrade >= iOpenGrade then
            self:CheckReward(oPlayer)
            self:GS2CGameReward(oPlayer)
            self:DelUpgradeEvent(oPlayer)
        end
    end
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("DAY_EXPENSE")
    if oToolMgr:IsSysOpen("DAY_EXPENSE", nil, true) then
        if oPlayer:GetGrade() < iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end
    if not global.oToolMgr:IsSysOpen("DAY_EXPENSE",oPlayer,true)  then return end
    if self.m_iState == GAME_OPEN then
            self:CheckReward(oPlayer)
            self:GS2CGameReward(oPlayer)
    end
    local FunCheck = function(iEventType, mData)
        local oCheckPlayer = mData.player
        self:CheckReward(oCheckPlayer)
    end
    oPlayer:AddEvent(self, gamedefines.EVENT.PLAYER_RESUME_TRUEGOLDCOIN, FunCheck)
end

function CHuodong:CheckReward(oPlayer)
    if self.m_iState ~= GAME_OPEN then 
        return
    end
    local mRewardConf = self:GetRewardConfig()
    if not mRewardConf then return end
    local pid = oPlayer:GetPid()
    local iTodayGoldCoinExpense = oPlayer.m_oTodayMorning:Query("today_expense_goldcoin",0)
    local bIsHasReward = false
    for _,mData in ipairs(mRewardConf) do
        local iPlayerExpense = mData.expense
        local iExpenseKey = mData.key
        if iTodayGoldCoinExpense >=  iPlayerExpense then
            if not self.m_mRewardInfo[pid] then
                self.m_mRewardInfo[pid] = {}
            end
            local mPlayerReward = self.m_mRewardInfo[pid]
            if not mPlayerReward[iExpenseKey] then
                mPlayerReward[iExpenseKey] = {}
                mPlayerReward[iExpenseKey].state = STATE_REWARD
                mPlayerReward[iExpenseKey].grid_list = {}
                self:Dirty()
                bIsHasReward = true
                local mLogData = {}
                mLogData.pid = pid
                mLogData.hd_id = self.m_iHDID
                mLogData.reward_group_key = self.m_sHD2RewardGroupKey
                mLogData.expense = iPlayerExpense
                record.log_db("huodong","dayexpense_reward",mLogData)
            end
        end
    end
    if bIsHasReward then
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:GetConfig()
    local sGroupKey = self.m_sHD2RewardGroupKey
    return res["daobiao"]["huodong"][self.m_sName]["config"][sGroupKey]
end

function CHuodong:GetRewardConfig()
    local sGroupKey = self.m_sHD2RewardGroupKey
    if sGroupKey then
        return res["daobiao"]["huodong"][self.m_sName]["reward"][sGroupKey]
    else
        return nil
    end
end

function CHuodong:SetGridChoice(oPlayer,sGroupKey,iExpenseKey,iGrid,iOption)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if self.m_iState ~= GAME_OPEN then
        return
    end
    if sGroupKey ~= self.m_sHD2RewardGroupKey then
        return
    end

    local  mRewardConf = self:GetRewardConfig()
    if not mRewardConf or not mRewardConf[iExpenseKey] then
        return
    end
    if not mRewardConf[iExpenseKey]["grid_list"][iGrid] or not mRewardConf[iExpenseKey]["grid_list"][iGrid][iOption] then
        return
    end

    local mPlayerReward = self.m_mRewardInfo[pid]
    if not mPlayerReward then
        return
    end
    local mExpenseReward = mPlayerReward[iExpenseKey]
    if not mExpenseReward then 
        return
    end
    if mExpenseReward.state == STATE_REWARD then
        self:Dirty()
        mExpenseReward.grid_list[iGrid] = iOption
        self:GS2CGameReward(oPlayer)
    end
end


function CHuodong:TryOpenRewardUI(oPlayer)
    self:GS2CGameReward(oPlayer)
end

-- 组装可领取信息
function CHuodong:GS2CGameReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerReward = self.m_mRewardInfo[pid] or {}
    local mRewardList = {}
    for iExpenseKey,mExpenseReward in pairs(mPlayerReward) do
        local mNetOneList = {}
        mNetOneList.reward_key = iExpenseKey
        mNetOneList.reward_state = mExpenseReward.state 
        local mGridList = {}
        if mExpenseReward.grid_list then
            for iGrid,iOption in pairs(mExpenseReward.grid_list) do
                table.insert(mGridList,{grid = iGrid,option = iOption })
            end
        end
        if next(mGridList) then
            mNetOneList.grid_list = mGridList
        end
        table.insert(mRewardList,mNetOneList)
    end
    local mNet = {
        group_key = self.m_sHD2RewardGroupKey,
        reward_list = mRewardList,
        goldcoin = oPlayer.m_oTodayMorning:Query("today_expense_goldcoin",0),
        end_time = self.m_iEndTime,
        state = self.m_iState,        
    }
    oPlayer:Send("GS2CDayExpenseReward",mNet)
end

function CHuodong:GetReward(oPlayer,sGroupKey,iExpenseKey)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if self.m_iState~= GAME_OPEN then
        return
    end
    if self.m_sHD2RewardGroupKey ~= sGroupKey then
        return
    end
    local  mRewardConf = self:GetRewardConfig()
    if not mRewardConf or not mRewardConf[iExpenseKey] then
        return
    end

    local mPlayerReward = self.m_mRewardInfo[pid]
    if not mPlayerReward then
        return
    end
    local mExpenseReward = mPlayerReward[iExpenseKey]
    if not mExpenseReward then 
        return
    end
    if mExpenseReward.state == STATE_REWARD then
        local mItemIdxList = self:GetGridReward(mExpenseReward,mRewardConf[iExpenseKey])
        local mItemList = {}
        for _,iItemIdx in ipairs(mItemIdxList) do
            -- templ initRewardItem  use reward/dayexpense/itemreward 
            local mItemUnit = self:InitRewardItem(oPlayer,iItemIdx,{})
            list_combine(mItemList,mItemUnit["items"]) 
        end
        if next(mItemList) then
            if not oPlayer:ValidGiveitemlist(mItemList,{cancel_tip = true}) then
                -- 背包满了无法领取
                oNotifyMgr:Notify(pid,self:GetTextData(1001))
                return
            end
            local mLogData = {}
            mLogData.pid = pid
            mLogData.hd_id = self.m_iHDID
            mLogData.reward_group_key = self.m_sHD2RewardGroupKey
            mLogData.expense = iExpenseKey
            mLogData.reward = extend.Table.serialize(mItemIdxList)
            record.log_db("huodong","dayexpense_rewarded",mLogData)
            oPlayer:GiveItemobj(mItemList,self.m_sName,{})
            self:Dirty()
            mExpenseReward.state = STATE_REWARDED
            self:GS2CGameReward(oPlayer)
        end
    end
end

function CHuodong:GetGridReward(mExpenseReward,mRewardConf)
    local mItemIdxList = {}
    for iGrid, lItemIdx in pairs(mRewardConf.grid_list) do
        local iOption = mExpenseReward.grid_list[iGrid] or 1
        table.insert(mItemIdxList,mRewardConf.grid_list[iGrid][iOption])
    end
    return mItemIdxList
end

function CHuodong:CheckSendMailReward()
    local mConfig = self:GetConfig()
    local iMailID = mConfig.mail
    local mRewardConf = self:GetRewardConfig()
    local oWorldMgr = global.oWorldMgr
    local lRewwardInfo = {}
    local lPlayerPid = {}
    for pid, mPlayerReward in pairs(self.m_mRewardInfo) do
        local mInfo = {
            pid = pid,
            reward = mPlayerReward,
        }
        table.insert(lRewwardInfo, mInfo)
        table.insert(lPlayerPid, pid)
    end
    self.m_mRewardInfo = {}
    self:Dirty()
    global.oToolMgr:ExecuteList(lPlayerPid,500, 500, 0, "DayExpenseRewarded", function(pid)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer.m_oTodayMorning:Set("today_expense_goldcoin",0)
            self:GS2CGameReward(oPlayer)
        end
    end)

    local function _InnerSendMail(mInfo)
        local mPlayerReward = mInfo.reward
        local pid = mInfo.pid
        local mItemList = {}
        for iExpenseKey,mExpenseReward in pairs(mPlayerReward) do
            local mItemIdxList = self:GetGridReward(mExpenseReward,mRewardConf[iExpenseKey])
            if mExpenseReward.state == STATE_REWARD then
                for _,iItemIdx in ipairs(mItemIdxList) do
                    local mRewardInfo  = self:GetItemRewardData(iItemIdx)
                    if not mRewardInfo then
                        goto continue
                    end
                    local mItemInfo = self:ChooseRewardKey(oPlayer,mRewardInfo,iItemIdx,{})
                    if not mItemInfo then
                        goto continue
                    end
                    local mItemUnit = self:InitRewardByItemUnitOffline(pid,iItemIdx,mItemInfo)
                    list_combine(mItemList,mItemUnit["items"])
                    ::continue::
                end
                local mLogData = {}
                mLogData.pid = pid
                mLogData.hd_id = self.m_iHDID
                mLogData.reward_group_key = self.m_sHD2RewardGroupKey
                mLogData.expense = iExpenseKey
                mLogData.reward = extend.Table.serialize(mItemIdxList)
                record.log_db("huodong","dayexpense_rewarded",mLogData)
            end
        end
        if next(mItemList) then
            local mMailReward = {}
            mMailReward["items"] = mItemList
            self:SendMail(pid,iMailID,mMailReward)
        end
    end
    global.oToolMgr:ExecuteList(lRewwardInfo,400,1*1000,0,"DayExpenseSendMail",_InnerSendMail)
end

function CHuodong:InitRewardByItemUnitOffline(pid,itemidx,mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback("dayexpense reward item"))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape,{})
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:NewDay(mNow)
    if self.m_iState == GAME_OPEN then
        self:CheckSendMailReward()
    end
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self.m_iState == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeStart")
            self:AddTimeCb("GameTimeStart",(self.m_iStartTime - iTime) * 1000,function ()
                self:DelTimeCb("GameTimeStart")
                if self.m_iState ~= GAME_READY_OPEN then return end
                self:GameStart()
            end)
        end
    elseif self.m_iState == GAME_OPEN then 
        if self.m_iEndTime <= iTime  then
            self:GameEnd()
        elseif self.m_iEndTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeEnd")
            self:AddTimeCb("GameTimeEnd",(self.m_iEndTime - iTime) * 1000,function ()
                self:DelTimeCb("GameTimeEnd")
                if self.m_iState ~= GAME_OPEN then return end
                self:CheckSendMailReward()
                self:GameEnd()
            end)
        end
    end
end

function CHuodong:IsHuodongOpen()
    if self.m_iState == GAME_OPEN then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag,mArgs)
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster,[[
gm  - huodongop dayexpense
101 - 查看玩家日消
102 - 增加玩家日消()(ex --102 { value = 100})
103 - 清空玩家日消(或者通过刷五点)
104 - 运营开启活动(ex -- 104 {hd_key = "reward_old"}) (hd_key 不填写默认为 reward_old)
105 - 运营关闭活动
106 - 领取奖励         (ex -- 106 {reward_key = 1})
107 - 邮件领取奖励
108 - 设置格子选项(ex -- 108 {reward_key = 1,grid = 3,option = 2})
109 - 查寻活动id
            ]])
    elseif iFlag == 101 then
        local iDayexpense = oMaster.m_oTodayMorning:Query("today_expense_goldcoin",0)
        local sMsg = global.oToolMgr:FormatString("当前日消#expense",{expense = iDayexpense})
        oMaster:NotifyMessage(sMsg)
    elseif iFlag == 102 then
        local oProfile = oMaster:GetProfile()
        local iVal = mArgs.value or 0
        if iVal > 0 then
            if oProfile:ValidGoldCoin(iVal,{}) then
                oProfile:ResumeGoldCoin(iVal,"GM dayexpense")
            end
        end
    elseif iFlag == 103 then
        oMaster.m_oTodayMorning:Set("today_expense_goldcoin",0)
    elseif iFlag == 104 then
        local iStartTime = get_time()
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        local mInfo = {
            hd_id = self.m_iHDID + 1,
            hd_type = "dayexpense",
            hd_key = "reward_old",
            start_time = iStartTime + 30,
            end_time = iStartTime + 2 * 24 * 3600
        }
        if mArgs and mArgs.hd_key then
            mInfo.hd_key = mArgs.hd_key
        end
        local bClose = false
        self.m_iEndTime = 10000
        self.m_iStartTime = 0
        self:RegisterHD(mInfo,bClose)
    elseif iFlag == 105 then
        local mInfo = {
            hd_type = "dayexpense",
        }
        local bClose = true
        self:RegisterHD(mInfo,bClose)
    elseif iFlag == 106 then
        self:GetReward(oMaster,self.m_sHD2RewardGroupKey,mArgs.reward_key)
    elseif iFlag == 107 then
        self:CheckSendMailReward()
    elseif iFlag ==108 then
        local iExpenseKey = mArgs.expense_key or 1
        local iGrid = mArgs.grid or 3
        local iOption = mArgs.option or 2
        self:SetGridChoice(oMaster,self.m_sHD2RewardGroupKey,iExpenseKey,iGrid,iOption)
   elseif iFlag == 109 then
        local sMsg = "每日累消活动id " .. self.m_iHDID
        global.oChatMgr:HandleMsgChat(oMaster,sMsg)
    elseif iFlag == 110 then
        local sMsg = os.date("%x %X",self.m_iStartTime) .. " --> " .. os.date("%x %X",self.m_iEndTime)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
   end
 end


