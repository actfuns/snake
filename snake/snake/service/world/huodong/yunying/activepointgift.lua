local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local STATE_UNREACH = 0
local STATE_REWARD = 1
local STATE_REWARDED = 2

local GAME_CLOSE = 0
local GAME_OPEN = 1
local GAME_READY_OPEN = 2

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "活跃礼包"
inherit(CHuodong, huodongbase.CHuodong)

-- 活跃度点数的列表排序使用
local function PointComp(a, b)
    return a < b
end

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_mRewardInfo = {}
    self.m_iHDID = 0
    self.m_sHD2RewardKey = ""
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:Save()
    local mData = {}
    mData.hd_id = self.m_iHDID
    mData.hd_key = self.m_sHD2RewardKey
    mData.hd_state = self.m_iState
    mData.start_time = self.m_iStartTime
    mData.end_time = self.m_iEndTime
    local mSaveInfo = {}
    for pid, mPlayerRewardInfo in pairs(self.m_mRewardInfo) do
        mSaveInfo[db_key(pid)] = mPlayerRewardInfo
    end
    mData.rewardinfo = mSaveInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iHDID = mData.hd_id or 0
    self.m_sHD2RewardKey = mData.hd_key or ""
    self.m_iState = mData.hd_state or 0
    self.m_iStartTime = mData.start_time
    self.m_iEndTime = mData.end_time
    local mSaveInfo = {}
    for sPid, mPlayerRewardInfo in pairs(mData.rewardinfo or {}) do
        mSaveInfo[tonumber(sPid)] = mPlayerRewardInfo
    end
    self.m_mRewardInfo = mSaveInfo
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong activepointgift without data"
    end
    if self.m_sHD2RewardKey ~= mFromData.hd_key then return true end
    if self.m_iState == GAME_OPEN and mFromData.hd_state == GAME_OPEN then
        for sPid, mReward in pairs(mFromData.rewardinfo or {}) do
            self.m_mRewardInfo[tonumber[sPid]] = mReward
        end
        self:Dirty()
    end
    return true
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    if  self.m_iState == GAME_OPEN then
        local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("ACTIVEPOINT_GIFT")
        if iFromGrade < iOpenGrade and iGrade >= iOpenGrade then
            self:GS2CActivePointGiftState(oPlayer)
            self:GS2CActivePointGiftTotalPoint(oPlayer)
            self:GS2COpenActivePointGiftView(oPlayer)
            self:DelUpgradeEvent(oPlayer)
        end
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local oToolMgr = global.oToolMgr
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("ACTIVEPOINT_GIFT")
    if oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT", nil , true) then
        if oPlayer:GetGrade() <  iOpenGrade then
            self:AddUpgradeEvent(oPlayer)
            return
        end
    end
    self:CheckKSLoginData(oPlayer)

    if not oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT", oPlayer, true) then return end
    if self.m_iState == GAME_OPEN then
        self:GS2CActivePointGiftState(oPlayer)
        self:GS2CActivePointGiftTotalPoint(oPlayer)
        self:GS2COpenActivePointGiftView(oPlayer)
    end
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:TryGameClose()
    else
        local bSucc, sError = self:CheckRegisterInfo(mInfo)
        if not bSucc then
            return false, sError
        end
        self:TryGameOpen(mInfo)
    end
    return true
end

function CHuodong:CheckRegisterInfo(mInfo)
    if not global.oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT", nil, true) then
        return false, "system closed"
    end
    if mInfo["hd_type"] ~= self.m_sName then
        return false, "no hd_type" .. mInfo["hd_type"]
    end
    local sHDkey = mInfo["hd_key"]
    if not sHDkey then
        return false, "no hd_key" .. mInfo["hd_key"]
    end
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][sHDkey]
    if not mConfig then
        return false, "no hd config"
    end
    if not mInfo["end_time"] or mInfo["end_time"] <= get_time() then
        return false, "end time error"
    end
    if not mInfo["start_time"] or mInfo["start_time"] >= mInfo["end_time"] then
        return false, "start time error"
    end
    local mCloseDate = os.date("*t", mInfo["end_time"])
    if mCloseDate.hour > 5 then
        mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
    elseif mCloseDate.hour == 5 then
        if mCloseDate.min > 0 or mCloseDate.sec > 0 then
            mInfo["end_time"] = mInfo["end_time"] + 24 * 3600
        end
    end
    mCloseDate = os.date("*t", mInfo["end_time"])
    mCloseDate.hour = 5
    mCloseDate.min = 0
    mCloseDate.sec = 0
    mInfo["end_time"] = os.time(mCloseDate)
    return true
end

function CHuodong:TryGameOpen(mInfo)
    if mInfo["hd_id"] ~= self.m_iHDID then
        self.m_iHDID = mInfo["hd_id"]
        self.m_sHD2RewardKey = mInfo["hd_key"]
        self.m_mRewardInfo = {}
    end
    self.m_iStartTime = mInfo["start_time"]
    self.m_iEndTime = mInfo["end_time"]
    self.m_iState = GAME_READY_OPEN
    self:Dirty()

    local iNowTime = get_time()
    if self.m_iStartTime <= iNowTime then
        self:GameStart()
    elseif self.m_iStartTime - iNowTime <= 3600 then
        self:DelTimeCb("GameTimeStart")
        self:AddTimeCb("GameTimeStart", (self.m_iStartTime - iNowTime) * 1000, function ()
            self:DelTimeCb("GameTimeStart")
            if self.m_iState ~= GAME_READY_OPEN then return end
            self:GameStart()
        end)
    end
end

function CHuodong:GameStart()
    self.m_iState = GAME_OPEN
    self:Dirty()

    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.reward_key = self.m_sHD2RewardKey
    mLogData.start_time = self.m_iStartTime
    mLogData.end_time = self.m_iEndTime
    record.log_db("huodong","activepointgift_state", {info = mLogData})
    local lAllOnlinePid = {}
    local oToolMgr = global.oToolMgr
    local oWorldMgr = global.oWorldMgr
    for _, oPlayer in pairs(oWorldMgr:GetOnlinePlayerList()) do
        if oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT", oPlayer, true) then
            table.insert(lAllOnlinePid, oPlayer:GetPid())
        end
    end
    oToolMgr:ExecuteList(lAllOnlinePid, 200, 1000, 0, "ActivePointGiftGameStart", function (pid)
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:CheckReward(oPlayer, 0, false)
        self:GS2CActivePointGiftState(oPlayer)
        self:GS2COpenActivePointGiftView(oPlayer)
    end)
    global.oHotTopicMgr:Register(self.m_sName)
    record.info("huodong yunying activepointgift start %d, %s",self.m_iHDID, self.m_sHD2RewardKey)
end

function CHuodong:TryGameClose(mInfo)
    self:GameEnd()
end

function CHuodong:GameEnd()
    self.m_iState = GAME_CLOSE
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:CheckSendMailReward()
    self:Dirty()
    local mLogData = {}
    mLogData.state = self.m_iState
    mLogData.hd_id = self.m_iHDID
    mLogData.hd_key = self.m_sHD2RewardKey
    mLogData.start_time = self.m_iStartTime
    mLogData.end_time = self.m_iEndTime
    record.log_db("huodong", "activepointgift_state", {info = mLogData})
    record.info("huodong yunying activepointgift end %d, %s",self.m_iHDID,self.m_sHD2RewardKey)
end

function CHuodong:GetPlayerRewardInfo(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerRewardInfo = self.m_mRewardInfo[pid]
    if not mPlayerRewardInfo then
        mPlayerRewardInfo = {}
        mPlayerRewardInfo.reward = {}
        mPlayerRewardInfo.totalpoint = oPlayer.m_oScheduleCtrl:GetTotalPoint()
        -- 记录已经达到的id
        mPlayerRewardInfo.reachlevel_id = 0
        self.m_mRewardInfo[pid] = mPlayerRewardInfo
    end
    return mPlayerRewardInfo
end

function CHuodong:CheckKSLoginData(oPlayer)
    local iTotal = oPlayer:Query("ks_activepoint_add", 0)
    oPlayer:Set("ks_activepoint_add", nil)
    if iTotal >= 0 then
        self:CheckReward(oPlayer, iTotal, true)
    end
end

function CHuodong:CheckReward(oPlayer, iPoint, bModule)
    if not global.oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT",oPlayer, true) then
        return
    end
    if self.m_iState ~= GAME_OPEN then
        return
    end
    local mRewardConfig = self:GetRewardConfig()
    if not mRewardConfig then return end
    local pid = oPlayer:GetPid()
    local mPlayerRewardInfo = self:GetPlayerRewardInfo(oPlayer)
    mPlayerRewardInfo.totalpoint = mPlayerRewardInfo.totalpoint + iPoint
    self:Dirty()
    self:GS2CActivePointGiftTotalPoint(oPlayer)
    local iTotalActivePoint = mPlayerRewardInfo.totalpoint
    local mConfig = self:GetConfig()
    
    local mNextLevel = mRewardConfig[mPlayerRewardInfo.reachlevel_id + 1]
    if not mNextLevel or mNextLevel.point > iTotalActivePoint then
        return
    end

    local iNextLevel = mNextLevel.point
    local bIsHasReward = false
    for _, mData in ipairs(mRewardConfig) do
        local iPointLevel = mData.point
        local iKey = mData.id
        if iPointLevel >= iNextLevel and iTotalActivePoint >= iPointLevel then
            local mPlayerReward = mPlayerRewardInfo.reward
            if not mPlayerReward[iKey] or mPlayerReward[iKey].state == STATE_UNREACH then
                if not mPlayerReward[iKey] then
                    mPlayerReward[iKey] = {}
                    mPlayerReward[iKey].state = STATE_REWARD
                    mPlayerReward[iKey].grid_list = {}
                elseif mPlayerReward[iKey].state == STATE_UNREACH then
                    mPlayerReward[iKey].state = STATE_REWARD
                end
               mPlayerRewardInfo.reachlevel_id = iKey
                self:Dirty()
                bIsHasReward = true
                local mLogData = {}
                mLogData.hd_id = self.m_iHDID
                mLogData.reward_key = self.m_sHD2RewardKey
                mLogData.pointlevel = iPointLevel
                mLogData.totalpoint = iTotalActionPoint
                record.log_db("huodong", "activepointgift_reward", {pid = pid, info = mLogData})
            end
        end
    end
    if bIsHasReward then
        self:GS2COpenActivePointGiftView(oPlayer)
    end
end

function CHuodong:ValidReward(oPlayer, iPointKey)
    if not global.oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT",oPlayer,true) then return end
    local pid = oPlayer:GetPid()
    if self.m_iState ~= GAME_OPEN then
        return false
    end
    local mRewardConf = self:GetRewardConfig()
    if not mRewardConf or not mRewardConf[iPointKey] then
        return false
    end

    local mPlayerRewardInfo = self:GetPlayerRewardInfo(oPlayer)
    local mPlayerReward = mPlayerRewardInfo.reward
    local mPointReward = mPlayerReward[iPointKey]
    if not mPointReward then
        return false
    end
    if mPointReward.state ~= STATE_REWARD then
        return false
    end
    return true
end

function CHuodong:GetReward(oPlayer, iPointKey)
    if not self:ValidReward(oPlayer, iPointKey) then return end
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local mRewardConf = self:GetRewardConfig()
    local mPlayerReward = self:GetPlayerRewardInfo(oPlayer).reward
    local mPointReward = mPlayerReward[iPointKey]
    if mPointReward.state == STATE_REWARD then
        local mItemIdxList = self:GetGridReward(mPointReward,mRewardConf[iPointKey])
        local mItemList = {}
        for _, iItemIdx in ipairs(mItemIdxList) do
            local mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {}) -- 由基类templ 提供
            list_combine(mItemList,mItemUnit["items"])
        end
        if next(mItemList) then
            if not oPlayer:ValidGiveitemlist(mItemList, {cancel_tip = true}) then
                oNotifyMgr:Notify(pid, self:GetTextData(1001))
                return
            end
            mPointReward.state = STATE_REWARDED
            oPlayer:GiveItemobj(mItemList, self.m_sName, {})
            self:Dirty()
            self:GS2COpenActivePointGiftView(oPlayer)
            local mLogData = {}
            mLogData.hd_id = self.m_iHDID
            mLogData.reward_key = self.m_sHD2RewardKey
            mLogData.point = iPointKey
            mLogData.reward = extend.Table.serialize(mItemIdxList)
            record.log_db("huodong","activepointgift_rewarded",{pid = pid, info = mLogData})    
        end
    end
end

function CHuodong:SetGridChoice(oPlayer,iPointKey,iGrid,iOption)
    if not global.oToolMgr:IsSysOpen("ACTIVEPOINT_GIFT",oPlayer, true) then return end
    if self.m_iState ~= GAME_OPEN then
        return
    end
    local pid = oPlayer:GetPid()
    local mRewardConf = self:GetRewardConfig()
    if not mRewardConf or not mRewardConf[iPointKey] then
        return
    end
    if not mRewardConf[iPointKey]["grid_list"][iGrid] or not mRewardConf[iPointKey]["grid_list"][iGrid][iOption] then
        return
    end
    local mPlayerRewardInfo = self:GetPlayerRewardInfo(oPlayer)
    local mPlayerReward = mPlayerRewardInfo.reward
    if not mPlayerReward[iPointKey] then
        mPlayerReward[iPointKey] = {}
        mPlayerReward[iPointKey].state = STATE_UNREACH
        mPlayerReward[iPointKey].grid_list = {}
    end
    local mPointReward = mPlayerReward[iPointKey]
    mPointReward["grid_list"][iGrid] = iOption
    local mNet = {
        point_key = iPointKey,
        grid_id = iGrid,
        option = iOption,
    }
    oPlayer:Send("GS2CActivePointSetGridOptionResult", mNet)
    self:Dirty()
end

function CHuodong:GetGridReward(mPointReward, mRewardConf)
    local mItemIdxList = {}
    for iGrid, lItemIdx in pairs(mRewardConf.grid_list) do
        local iOption = mPointReward.grid_list[iGrid] or 1
        table.insert(mItemIdxList,mRewardConf.grid_list[iGrid][iOption])
    end
    return mItemIdxList
end

function CHuodong:GS2COpenActivePointGiftView(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerRewardInfo  = self:GetPlayerRewardInfo(oPlayer)
    local mPlayerReward = mPlayerRewardInfo.reward

    local mRewardList = {}
    for iPointKey, mPointReward in pairs(mPlayerReward) do
        local mNetOneList = {}
        mNetOneList.point_key = iPointKey
        mNetOneList.reward_state = mPointReward.state
        local mGridList = {}
        if mPointReward.grid_list then
            for iGrid, iOption in pairs(mPointReward.grid_list) do
                table.insert(mGridList, {grid_id = iGrid, option = iOption})
            end
        end
        if next(mGridList) then
            mNetOneList.grid_list = mGridList
        end
        table.insert(mRewardList, mNetOneList)
    end
    local mNet = {
        gift_list = mRewardList,
    }
    oPlayer:Send("GS2COpenActivePointGiftView",mNet)
end

function CHuodong:GS2CActivePointGiftTotalPoint(oPlayer)
    local pid = oPlayer:GetPid()
    local mPlayerRewardInfo = self:GetPlayerRewardInfo(oPlayer)
    local iTotalActivePoint = mPlayerRewardInfo.totalpoint
    oPlayer:Send("GS2CActivePointGiftTotalPoint",{ total_point = iTotalActivePoint})
end

function CHuodong:C2GSOpenActivePointGiftView(oPlayer)
    if self.m_iState ~= GAME_OPEN then
        return
    end
    self:GS2CActivePointGiftState(oPlayer)
    self:GS2CActivePointGiftTotalPoint(oPlayer)
    self:GS2COpenActivePointGiftView(oPlayer)
end

function CHuodong:GS2CActivePointGiftState(oPlayer)
    local mNet = {
        state = self.m_iState,
        end_time = self.m_iEndTime,
    }
    oPlayer:Send("GS2CActivePointGiftState",mNet)
end

function CHuodong:CheckSendMailReward()
    local mConfig = self:GetConfig()
    local iMailID = mConfig.mail
    local mRewardConf = self:GetRewardConfig()
    local oWorldMgr = global.oWorldMgr
    local lRewardInfo = {}
    local mInfo
    for pid, mPlayerRewardInfo in pairs(self.m_mRewardInfo) do
        mInfo = {
            pid = pid,
            reward = mPlayerRewardInfo.reward
        }
        table.insert(lRewardInfo, mInfo)
    end
    self.m_mRewardInfo = {}
    self:Dirty()
    local _InnerSendMail = function (mInfo)
        local pid = mInfo.pid
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            self:GS2CActivePointGiftState(oPlayer)
        end
        local mPlayerReward = mInfo.reward
        local mItemList = {}
        for iPointKey, mPointReward in pairs(mPlayerReward) do
            local mItemIdxList = self:GetGridReward(mPointReward, mRewardConf[iPointKey])
            if mPointReward.state == STATE_REWARD then
                for _, iItemIdx in ipairs(mItemIdxList) do
                    local mRewardInfo = self:GetItemRewardData(iItemIdx)
                    if not mRewardInfo then
                        goto continue
                    end
                    local mItemInfo = self:ChooseRewardKey(nil, mRewardInfo, iItemIdx, {})
                    if not mItemInfo then
                        goto continue
                    end
                    local mItemUnit = self:InitRewardByItemUnitOffline(pid, iItemIdx, mItemInfo)
                    list_combine(mItemList, mItemUnit["items"])
                    ::continue::
                end
                local mLogData = {}
                mLogData.hd_id = self.m_iHDID
                mLogData.reward_key = self.m_sHD2RewardKey
                mLogData.point = iPointKey
                mLogData.reward = extend.Table.serialize(mItemIdxList)
                record.log_db("huodong","activepointgift_rewarded",{pid = pid, info = mLogData})
            end
        end
        if next(mItemList) then
            local mMailReward = {}
            mMailReward["items"] = self:_RewardItemMerge(mItemList)
            self:SendMail(pid, iMailID, mMailReward)
        end
    end
    global.oToolMgr:ExecuteList(lRewardInfo, 400 , 1000, 0, "ActivePointGiftSendMail", _InnerSendMail)
end

function CHuodong:_RewardItemMerge(mItemList)
    local mShape = {}
    local sid
    for _, oItemobj in pairs(mItemList) do
        sid = oItemobj:SID()
        if not mShape[sid] then
            mShape[sid] = {}
        end
        table.insert(mShape[sid], oItemobj)
    end

    for sid, lItemobj in pairs(mShape) do
        if #lItemobj >= 2 then
            if not lItemobj[1]:ValidCombine(lItemobj[2]) then
                goto continue
            end

            if lItemobj[1]:ItemType() == "virtual" then
                local oDest = lItemobj[1]
                local oSrc
                local iDestAmount
                local iSrcAmount
                local iTotalValue = oDest:GetVirtualItemValue()
                for index = 2, #lItemobj do
                    oSrc = lItemobj[index]
                    iTotalValue = iTotalValue + oSrc:GetVirtualItemValue()
                    -- 将数目置为 0 过滤掉物品
                    oSrc:SetAmount(0)
                end
                oDest:SetVirtualItemValue(iTotalValue)
                if oDest:GetAmount() <= 0 then
                    oDest:SetAmount(1)
                end
                goto continue
            end

            local oDest = lItemobj[1]
            local iDestAmount
            local iMaxAmount = oDest:GetMaxAmount()
            local iSrc = 2
            local oSrc = lItemobj[iSrc]
            local iSrcAmount
            while(oDest and oSrc) do
                iDestAmount = oDest:GetAmount()
                iSrcAmount = oSrc:GetAmount()
                local iAddAmount = math.min(math.max(iMaxAmount - iDestAmount, 0), iSrcAmount)
                oDest:SetAmount(iDestAmount + iAddAmount)
                oSrc:SetAmount(iSrcAmount - iAddAmount)
                if oDest:GetAmount() >= iMaxAmount  then
                    if oSrc:GetAmount()  > 0 then 
                        oDest = oSrc
                        iSrc = iSrc + 1
                        oSrc = lItemobj[iSrc]
                    else
                        -- oDest:Amount() == iMaxAmount and oSrc:Amount() == 0 替换目标和源
                        oDest = lItemobj[iSrc + 1]
                        oSrc = lItemobj[iSrc + 2]
                        iSrc = iSrc + 2
                    end
                else
                    iSrc = iSrc + 1
                    oSrc = lItemobj[iSrc]
                end
            end
        end
        ::continue::
    end

    local lRetItemlist = {}
    for _, lItemobj in pairs(mShape) do
        for _, oItemobj in pairs(lItemobj) do
            if oItemobj and oItemobj:GetAmount() > 0 then
                table.insert(lRetItemlist, oItemobj)
            end  
        end
    end

    return lRetItemlist
end

function CHuodong:InitRewardByItemUnitOffline(pid, itemidx, mItemInfo)
    local mItems = {}
    mItems["items"] = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback("activepointgift reward item"))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape, {})
    -- 虚拟货币直接返回
    if oItem:ItemType() == "virtual" then
        if iBind ~= 0 then
            oItem:Bind(pid)
        end
        oItem:SetAmount(iAmount)
        table.insert(mItems["items"],oItem)
        return mItems
    end

    -- 获得最大叠加数
    local iMaxAmount = oItem:GetMaxAmount()
    -- 置空重新创建只是为了逻辑容易看些（多了一次ExtCreate调用）
    oItem = nil
    while(iAmount > iMaxAmount) do
        oItem = global.oItemLoader:ExtCreate(sShape,{})
        oItem:SetAmount(iMaxAmount)
        if iBind ~= 0 then
            oItem:Bind(pid)
        end
        table.insert(mItems["items"],oItem)
        iAmount = iAmount - iMaxAmount
    end

    if  iAmount > 0 then
        oItem = global.oItemLoader:ExtCreate(sShape,{})
        oItem:SetAmount(iAmount)
        if iBind ~= 0 then
            oItem:Bind(pid)
        end
        table.insert(mItems["items"], oItem)
    end
    return mItems
end

function CHuodong:GetRewardByGoldCoin(oPlayer,iPointKey)
    local pid = oPlayer:GetPid()
    local mPlayerRewardInfo = self:GetPlayerRewardInfo(oPlayer)
    local mPlayerReward = mPlayerRewardInfo.reward
    local iTotalActionPoint = mPlayerRewardInfo.totalpoint
    local mRewardConf = self:GetRewardConfig()
    if not mRewardConf[iPointKey] then return end
    local iDiffPoint = mRewardConf[iPointKey].point - iTotalActionPoint
    local mConfig = self:GetConfig()
    local iCost = math.ceil(formula_string(mConfig.change, {point = iDiffPoint}))

    if iCost > 0 then
        if not oPlayer:ValidGoldCoin(iCost) then

            return
        end
    else
        return
    end

    local mPointReward = mPlayerReward[iPointKey]
    if not mPointReward then
        mPointReward = {}
        mPointReward.grid_list = {}
        mPointReward.state = STATE_UNREACH

        mPlayerReward[iPointKey] = mPointReward
    end

    -- 只有未达到的才可元宝购买
    if mPointReward.state ~= STATE_UNREACH then
        return
    end

    local mItemIdxList = self:GetGridReward(mPointReward, mRewardConf[iPointKey])
    local mItemList = {}
    local mItemUnit
    for _, iItemIdx in ipairs(mItemIdxList) do
        mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
        list_combine(mItemList, mItemUnit["items"])
    end
    if next(mItemList) then
        if not oPlayer:ValidGiveitemlist(mItemList, {cancel_tip = true}) then
           global.oNotifyMgr:Notify(pid, self:GetTextData(1001))
           return
       end
       -- 再判断一次
       if not oPlayer:ValidGoldCoin(iCost) then return end
        oPlayer:ResumeGoldCoin(iCost, "购买活跃礼包")

        mPointReward.state = STATE_REWARDED
        self:Dirty()
        -- 奖励获得日志
        local mLogData = {}
        mLogData.hd_id = self.m_iHDID
        mLogData.reward_key = self.m_sHD2RewardKey
        mLogData.pointlevel = iPointKey
        mLogData.totalpoint = iTotalActionPoint
        mLogData.goldcoin = iDiffPoint
        mLogData.reward = extend.Table.serialize(mItemIdxList)
        record.log_db("huodong","activepointgift_rewarded",{pid = pid, info = mLogData})
        oPlayer:GiveItemobj(mItemList, self.m_sName, {})
        self:GS2COpenActivePointGiftView(oPlayer)
    end
end

function CHuodong:NewDay(mNow)
    if self.m_iState == GAME_OPEN then
    end
end

function CHuodong:NewHour(mNow)
    local iTime = mNow and mNow.time or get_time()
    if self.m_iState == GAME_READY_OPEN then
        if self.m_iStartTime <= iTime then
            self:GameStart()
        elseif self.m_iStartTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeStart")
            self:AddTimeCb("GameTimeStart", (self.m_iStartTime - iTime) * 1000, function()
                self:DelTimeCb("GameTimeStart")
                if self.m_iState ~= GAME_READY_OPEN then return end
                self:GameStart()
                end)
        end
    elseif self.m_iState == GAME_OPEN then
        if self.m_iEndTime <= iTime then
            self:GameEnd()
        elseif self.m_iEndTime - iTime <= 3600 then
            self:DelTimeCb("GameTimeEnd")
            self:AddTimeCb("GameTimeEnd", (self.m_iEndTime - iTime) * 1000, function ()
                self:DelTimeCb("GameTimeEnd")
                if self.m_iState ~= GAME_OPEN then return end
                self:GameEnd()
            end)
        end
    end
end

function CHuodong:GetRewardConfig()
    local sRewardKey = self.m_sHD2RewardKey
    if sRewardKey then
        return res["daobiao"]["huodong"][self.m_sName][sRewardKey]
    else
        return nil
    end
end

function CHuodong:GetConfig()
    local sRewardKey = self.m_sHD2RewardKey
    return res["daobiao"]["huodong"][self.m_sName]["config"][sRewardKey]
end

function CHuodong:IsHuodongOpen()
    if self.m_iState == GAME_OPEN then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local oChatMgr = global.oChatMgr
    if iFlag == 100 then
        oChatMgr:HandleMsgChat(oMaster,[[
gm - huodongop activepoint
101 - 增加玩家活跃（仅限于该活动）(ex -- 101 {value = 100})
102 - 清空玩家活跃（仅限于该活动）
103 - 查看玩家活跃
104 - 运营开启活动
105 - 运营关闭活动
106 - 领取奖励      (ex -- 106 {point_key = 1}
107 - 全服邮件发送奖励
108 - 使用元宝领取奖励
109 - 设置格子选项(ex -- 108 (point_key = 1, grid = 3, option = 2))
110 - 查询活动id
111 - 奖励状态可领取 (ex -- 111 {point_key = 1})
            ]])
    elseif iFlag == 101 then
        mArgs.value = mArgs.value or 50
        if mArgs.value > 0 then
            self:CheckReward(oMaster, mArgs.value, false)
        end
    elseif iFlag == 102 then
            self.m_mRewardInfo[pid].totalpoint = 0
            self.m_mRewardInfo[pid].reward = {}
            self.m_mRewardInfo[pid].reachlevel = 0
    elseif iFlag == 103 then
        global.oNotifyMgr:Notify(pid,"活跃度" .. self.m_mRewardInfo[pid].totalpoint)
    elseif iFlag == 104 then
        local iStartTime = get_time()
        if not self.m_iHDID then
            self.m_iHDID = 0
        end
        local mInfo = {
            hd_id = self.m_iHDID + 1,
            hd_type = "activepoint",
            hd_key = "reward",
            start_time = iStartTime + 5,
            end_time = iStartTime + 2 * 24 * 3600,
        }
        local bClose = false
        self.m_iEndTime = 10000
        self.m_iStartTime = 0
        self:RegisterHD(mInfo, bClose)
    elseif iFlag == 105 then
        local mInfo = {
            hd_type = "activepoint",
        }
        local bClose = true
        self:RegisterHD(mInfo,bClose)
    elseif iFlag == 106 then
        self:GetReward(oMaster, mArgs.point_key)
    elseif iFlag == 107 then
        self:CheckSendMailReward()
    elseif iFlag == 108 then
        self:GetRewardByGoldCoin(oMaster, mArgs.point_key)
    elseif iFlag == 109 then
        local iPointKey = mArgs.point_key or 1
        local iGrid = mArgs.grid or 3
        local iOption = mArgs.option or 2
        self:SetGridChoice(oMaster, iPointKey, iGrid, iOption)
        elseif iFlag == 110 then
            local sMsg = "活跃礼包活动id ： " .. self.m_iHDID .. "状态" .. self.m_iState
            global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    elseif iFlag == 111 then
        local mPlayerReward = self.m_mRewardInfo[pid].reward
        local iPointKey = mArgs.point_key or 1
        local mPointReward = mPlayerReward[iPointKey]
        if mPointReward then
            mPointReward.state = STATE_REWARD
        end
    elseif iFlag == 112 then
        local sMsg = os.date("%x %X",self.m_iStartTime) .. "-->" .. os.date("%x %X",self.m_iEndTime)
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end
