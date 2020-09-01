local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "每日累充"
inherit(CHuodong, huodongbase.CHuodong)

local NEW_MODE = 1 --新服模式
local OLD_MODE = 2 --老服模式
local THIRD_MODE = 3 --第三套新模式

local GAME_START = 1
local GAME_NOSTART = 0

function LevelSort(a,b)
    return a<b
end

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iVersion = 0
    o.m_mRewardInfo = {}
    o.m_iOpenDay = 0
    o.m_iMode = 0
    o.m_iGameDay = 0
    return o
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:Save()
    local mData = {}
    mData.version = self.m_iVersion
    mData.openday = self.m_iOpenDay
    mData.mode = self.m_iMode
    mData.gameday = self.m_iGameDay
    local mRewardInfo = {}
    for pid,mReward in pairs(self.m_mRewardInfo) do
        mRewardInfo[db_key(pid)]  = table_to_db_key(mReward)
    end
    mData.rewardinfo = mRewardInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    self.m_iVersion = mData.version or 0
    self.m_iOpenDay = mData.openday or 0
    self.m_iMode = mData.mode or 0
    self.m_iGameDay = mData.gameday or 0
    local mRewardInfo = {}
    for sPid,mReward in pairs(mData.rewardinfo or {}) do
        mRewardInfo[tonumber(sPid)]  = table_to_int_key(mReward)
    end
    self.m_mRewardInfo = mRewardInfo
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong totalcharge without data"
    end
    self:Dirty()
    for sPid, mReward in pairs(mFromData.rewardinfo or {}) do
        self.m_mRewardInfo[tonumber(sPid)]  = table_to_int_key(mReward)
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:NewDay(mNow)
    if self:GetGameState(true) == GAME_START then
        self:CheckGiveReward()
        self:TryGameEnd(mNow)
    end
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self:GetGameState() == GAME_START then
        self:GS2CGameStart(oPlayer)
        if not bReEnter then
            self:CheckReward(oPlayer)
        end
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:GetGameState(bNewDay)
    if self.m_iOpenDay ==0  then
        return GAME_NOSTART
    end
    local iCurDay = get_morningdayno()
    local iGameDay = self:GetGameDay()
    assert(iGameDay>0,string.format("%s gameday error %s",self.m_sName,iGameDay))
    if iCurDay>=self.m_iOpenDay and iCurDay<=self.m_iOpenDay+iGameDay then
        return GAME_START 
    elseif iCurDay == self.m_iOpenDay+iGameDay +1 and bNewDay then
        return GAME_START
    end
    return GAME_NOSTART
end

function CHuodong:GetEndTime()
    if self:GetGameState() ~= GAME_START then
        return 0
    end
    local iGameDay = self:GetGameDay()
    local iEndDay = self.m_iOpenDay + iGameDay
    local iCurDay = get_morningdayno()
    local iTime = get_time() + (iEndDay-iCurDay) * 3600 * 24
    local date = os.date("*t",iTime)
    local iEndTime=0
    if date.hour>=5 then
        iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=5,min=0,sec=0})
    else
        iTime = iTime - 5*60*60
        date = os.date("*t",iTime)
        iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=5,min=0,sec=0})
    end
    return iEndTime
end

--运营开启活动接口
function CHuodong:TryGameStart(oPlayer,iMode,iGameDay)
    if self:GetGameState() == GAME_START then
        if oPlayer then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        end
        record.warning(string.format("%s gamestart error1 %s %s", self.m_sName,iGameDay,iMode)) 
        return
    end
    if iMode ~= NEW_MODE and iMode ~= OLD_MODE and iMode ~= THIRD_MODE then
        if oPlayer then
            global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1002))
        end
        record.warning(string.format("%s gamestart error2 %s %s", self.m_sName,iGameDay,iMode)) 
        return
    end
    self:GameStart(iMode,iGameDay)
end

function CHuodong:RegisterHD(mInfo, bClose)
    if bClose then
        self:GameEnd()
        record.warning(string.format("%s force gameend", self.m_sName)) 
    else
        local iEndTime = mInfo.end_time
        if iEndTime>0 then
            local iStartTime = get_time()
            local iEndTime = mInfo.end_time
            local iStartDay = get_morningdayno(iStartTime)
            local iEndDay = get_morningdayno(iEndTime)
            local iGameDay = 1
            iGameDay = math.max(iGameDay,iEndDay-iStartDay+1)
            local sHDKey = mInfo.hd_key
            local iMode = 0
            if sHDKey == "new" then
                iMode=1
            elseif sHDKey == "old" then
                iMode=2
            elseif sHDKey == "third" then
                iMode = 3
            end
            self:TryGameStart(nil,iMode,iGameDay)
        end
    end
    return true
end

function CHuodong:GameStart(iMode,iGameDay)
    self:Dirty()
    self.m_iMode = iMode
    self.m_iVersion = self.m_iVersion +1 
    self.m_mRewardInfo = {}
    self.m_iOpenDay = get_morningdayno()
    self.m_iGameDay = iGameDay
    record.info(string.format("%s GameStart %s %s",self.m_sName,self.m_iOpenDay,iGameDay))
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    mLogData.mode = self.m_iMode
    record.log_db("huodong", "totalcharge_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
            self:GS2CGameStart(oPlayer)
            self:CheckReward(oPlayer)
            self:GS2CGameReward(oPlayer)
    end
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:TryGameEnd(mNow)
    local iTime = mNow and mNow.time or get_time()
    local iCurDay = get_morningdayno(iTime)
    local iGameDay = self:GetGameDay()
    assert(iGameDay>0,string.format("%s gameday error %s",self.m_sName,iGameDay))
    if iCurDay>=self.m_iOpenDay+iGameDay then
        self:GameEnd()
    end
end

function CHuodong:GetGameDay()
    if self.m_iGameDay>0 then
        return self.m_iGameDay
    end
    local iGameDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    return  iGameDay
end

function CHuodong:GameEnd()
    global.oHotTopicMgr:UnRegister(self.m_sName)
    self:Dirty()
    self.m_mRewardInfo = {}
    self.m_iOpenDay = 0
    self.m_iGameDay = 0
    local iMode = self.m_iMode
    self.m_iMode = 0
    record.info(string.format("%s GameEnd %s",self.m_sName,self.m_iOpenDay))
    local mLogData = {}
    mLogData.state = self:GetGameState()
    mLogData.version = self.m_iVersion
    mLogData.mode = iMode
    record.log_db("huodong", "totalcharge_state",mLogData)
    for _,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        self:GS2CGameEnd(oPlayer)
    end
end

function CHuodong:GetReward(oPlayer,iLevel)
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        global.oNotifyMgr:Notify(pid,self:GetTextData(1003))
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    local mRewardData = self:GetRewardDataByMode()
    if not mRewardData[iLevel] then
        return
    end
    local mLevelReward = mReward[iLevel]
    if not mLevelReward then
        return
    end
    local iReward = mLevelReward.reward or 0
    local iRewarded = mLevelReward.rewarded or 0
    if iReward ~= 1 then
        return
    end
    if iRewarded~=0 then
        return
    end
    local rewardlist = self:GetSlotReward(mLevelReward,mRewardData[iLevel])
    if #rewardlist<=0 then
        return
    end

    local itemlist = {}
    for _,iItemRewardIdx in ipairs(rewardlist) do
        local iteminfo = self:InitRewardItem(oPlayer,iItemRewardIdx,{})
        list_combine(itemlist,iteminfo["items"])
    end
    if #itemlist<0 then
        return
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<#itemlist then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(3015))
        return false
    end
    if not oPlayer:ValidGiveitemlist(itemlist,{cancel_tip = true}) then
        oNotifyMgr:Notify(pid,self:GetTextData(1004))
        return
    end
    local mLogData = {}
    mLogData.pid = pid
    mLogData.version = self.m_iVersion
    mLogData.mode = self.m_iMode
    mLogData.level = iLevel
    mLogData.reward = extend.Table.serialize(rewardlist)
    record.log_db("huodong", "totalcharge_rewarded",mLogData)
    oPlayer:GiveItemobj(itemlist,self.m_sName,{})
    self:Dirty()
    mLevelReward.rewarded = 1
    self:GS2CGameReward(oPlayer)
end

function CHuodong:GetSlotReward(mLevelReward,mRewardData)
    local rewardlist = {}
    for sSlot,mSlotReward in pairs(mRewardData) do
        if not string.find(sSlot,"slot") then
            goto continue
        end
        if #mSlotReward<=0 then
            goto continue
        end
        local iSlot = mLevelReward[sSlot] or 1
        if not mSlotReward[iSlot] then
            iSlot = 1
        end
        table.insert(rewardlist,mSlotReward[iSlot])
        ::continue::
    end
    return rewardlist
end

function CHuodong:SetChoice(oPlayer,iLevel,iSlot,iIndex)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        return
    end
    local mRewardRes = self:GetRewardDataByMode()
    if not mRewardRes[iLevel] then
        return
    end
    local sSlot = string.format("slot%s",iSlot)
    if not mRewardRes[iLevel][sSlot] then
        return
    end
    if not mRewardRes[iLevel][sSlot][iIndex] then
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    local mLevelReward = mReward[iLevel]
    if not mLevelReward then
        return
    end
    local iReward = mLevelReward.reward or 0
    local iRewarded = mLevelReward.rewarded or 0
    if iReward~=1 then
        return
    end
    if iRewarded~=0 then
        return
    end
    self:Dirty()
    mLevelReward[sSlot]  = iIndex
    self:GS2CGameReward(oPlayer)
end

function CHuodong:CheckReward(oPlayer,sProductKey)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if self:GetGameState() ~= GAME_START then
        return
    end
    -- local iLimitGrade= res["daobiao"]["open"]["TOTAL_CHARGE"]["p_level"]
    -- if oPlayer:GetGrade()<iLimitGrade then
    --     return
    -- end
    if sProductKey then
        local mPayData = res["daobiao"]["pay"][sProductKey]
        if mPayData["func"] ~= "pay_for_gold" then
            return
        end
    end
    local mData = self:GetRewardDataByMode()
    local levellist = table_key_list(mData)
    table.sort(levellist,LevelSort)
    local iTodayGoldCoin = oPlayer.m_oTodayMorning:Query(gamedefines.TODAY_PAY_GOLDCOIN,0)
    local bSend = false
    for _,iLevel in ipairs(levellist) do
        if iTodayGoldCoin>=iLevel then
            self:Dirty()
            if not self.m_mRewardInfo[pid] then
                self.m_mRewardInfo[pid] = {}
            end
            local mReward = self.m_mRewardInfo[pid]
            if not mReward[iLevel] then
                mReward[iLevel] = {}
            end
            local mLevelReward = mReward[iLevel]
            local iReward = mLevelReward.reward or 0
            if iReward==0 then
                mLevelReward.reward = 1
                mLevelReward.rewarded = 0
            end
            mReward[iLevel] = mLevelReward
            self.m_mRewardInfo[pid] = mReward
            bSend = true
            local mLogData = {}
            mLogData.pid = pid
            mLogData.version = self.m_iVersion
            mLogData.mode = self.m_iMode
            mLogData.level = iLevel
            record.log_db("huodong", "totalcharge_reward",mLogData)
        end
    end
    if bSend then
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:CheckGiveReward()
    self:Dirty()
    local iMailID = res["daobiao"]["huodong"][self.m_sName]["config"][1]["mail"]
    local mRewardInfo = self.m_mRewardInfo
    self.m_mRewardInfo = {}
    local mRewardData = self:GetRewardDataByMode()
    local oWorldMgr = global.oWorldMgr
    local oMailMgr = global.oMailMgr
    for pid,mReward in pairs(mRewardInfo) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        local itemlist = {}
        for iLevel,mLevelReward in pairs(mReward) do
            local iReward = mLevelReward.reward or 0
            local iRewarded = mLevelReward.rewarded or 0
            if iReward ~= 1 then
                goto continue
            end
            if iRewarded~=0 then
                goto continue
            end
            if not mRewardData[iLevel] then
                goto continue
            end
            local rewardlist = self:GetSlotReward(mLevelReward,mRewardData[iLevel])
            if #rewardlist<=0 then
                goto continue
            end
            for _,iItemRewardIdx in ipairs(rewardlist) do
                local mRewardInfo = self:GetItemRewardData(iItemRewardIdx)
                if not mRewardInfo then
                    goto continue2
                end
                local mItemInfo = self:ChooseRewardKey(oPlayer, mRewardInfo, iItemRewardIdx, {})
                if not mItemInfo then
                    goto continue2
                end
                local iteminfo = self:InitRewardByItemUnitOffline(pid,iItemRewardIdx,mItemInfo)
                list_combine(itemlist,iteminfo["items"])
                ::continue2::
            end
            local mLogData = {}
            mLogData.pid = pid
            mLogData.version = self.m_iVersion
            mLogData.mode = self.m_iMode
            mLogData.level = iLevel
            mLogData.reward = extend.Table.serialize(rewardlist)
            record.log_db("huodong", "totalcharge_rewarded",mLogData)
            ::continue::
        end
        if #itemlist>0 then
            local mMailReward = {}
            mMailReward["items"] = itemlist
            self:SendMail(pid,iMailID,mMailReward)
        end
        if oPlayer then
            self:GS2CGameReward(oPlayer)
        end
    end
end


function CHuodong:InitRewardByItemUnitOffline(pid, itemidx, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback(""))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape, {})
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:GetRewardDataByMode()
    if self.m_iMode == NEW_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["new_reward"]
    elseif self.m_iMode == OLD_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["old_reward"]
    elseif self.m_iMode == THIRD_MODE then
        return res["daobiao"]["huodong"][self.m_sName]["third_reward"]
    end
end

function CHuodong:GS2CGameStart(oPlayer)
    local mNet = {}
    mNet.endtime = self:GetEndTime()
    mNet.mode = self.m_iMode
    oPlayer:Send("GS2CTotalChargeStart",mNet)
end

function CHuodong:GS2CGameEnd(oPlayer)
    oPlayer:Send("GS2CTotalChargeEnd",{})
end

function CHuodong:GS2CGameReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mNet = {}
    local mReward = self.m_mRewardInfo[pid] or {}
    local rewardlist = {}
    for iLevel,mLevelReward in pairs(mReward) do
        local mRewardNet = {}
        mRewardNet.level = iLevel
        mRewardNet.reward = mLevelReward.reward or 0
        mRewardNet.rewarded = mLevelReward.rewarded or 0
        local mSlotNet = {}
        for k,v in pairs(mLevelReward) do
            local iStart,iEnd = string.find(k,"slot") 
            if iStart and iEnd then
                local iSlot = tonumber(string.sub(k,iEnd+1,#k))
                if iSlot then
                    table.insert(mSlotNet,{slot = iSlot,index = v })
                end
            end
        end
        mRewardNet.slotlist = mSlotNet
        table.insert(rewardlist,mRewardNet)
    end
    mNet.rewardlist = rewardlist
    mNet.todaygoldcoin  = oPlayer.m_oTodayMorning:Query(gamedefines.TODAY_PAY_GOLDCOIN,0)
    oPlayer:Send("GS2CTotalChargeReward",mNet)
end

function CHuodong:IsHuodongOpen()
    if self:GetGameState() == GAME_START then
        return true
    else
        return false
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101 活动开始（1:新 2:老）\nhuodongop totalcharge 101  {mode=1,day = 1}",
        "102 活动结束\nhuodongop totalcharge 102",
    }
    --sethdcontrol totalcharge old 0 60
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        local iMode = mArgs.mode or 0
        local iDay = mArgs.day  or 1
        self:TryGameStart(oPlayer,iMode,iDay)
        if self:GetGameState() == GAME_START then
            oNotifyMgr:Notify(pid,"开启成功")
        else
            oNotifyMgr:Notify(pid,"开启失败")
        end
    elseif iFlag == 102 then
        self:GameEnd()
        oNotifyMgr:Notify(pid,"关闭成功")
    elseif iFlag == 201 then -- huodongop everydaycharge 201 {pay=30,day=1}
        self:GetReward(oPlayer,mArgs.level)
    elseif iFlag == 202 then 
        self:SetChoice(oPlayer,mArgs.level,mArgs.slot,mArgs.index)
    elseif iFlag == 203 then
        self:CheckGiveReward()
    end
end