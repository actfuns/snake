--离线档案
local skynet = require "skynet"
local global = require "global"
local interactive = require "base.interactive"
local extend = require "base/extend"
local record = require "public.record"

local defines = import(service_path("offline.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local analy = import(lualib_path("public.dataanaly"))


CProfileCtrl = {}
CProfileCtrl.__index = CProfileCtrl
inherit(CProfileCtrl, CBaseOfflineCtrl)

function CProfileCtrl:New(iPid)
    local o = super(CProfileCtrl).New(self, iPid)
    o.m_sDbFlag = "Profile"

    o.m_iGoldCoin = 0
    o.m_iRplGoldCoin = 0
    o.m_iGoldCoinOwe  = 0   --默认元宝欠费
    o.m_iTrueGoldCoinOwe = 0 -- 非绑定元宝欠费
    o.m_mUpvote = {}        --点赞
    o.m_mUpvoteReward = {}  -- 点赞奖励
    o.m_mTitleInfo = {}     -- 称谓
    o.m_mTouxianInfo = {}
    o.m_iFrozenSession = 0
    o.m_mFrozenMoney = {}
    o.m_iShowId = iPid
    o.m_iRoleType = 0
    o.m_iCouplePid = 0
    o.m_mTodayMorning = {}

    -- 一些log信息
    o.m_sIP = ""
    o.m_sMac = ""
    o.m_sDevice = ""
    o.m_iPlatform = 0
    o.m_sAccount = ""
    o.m_iChannel = 0
    o.m_sCpsChannel = ""
    o.m_sUDID = ""
    o.m_iLastOnlineTime = 0
    return o
end

function CProfileCtrl:Save()
    local data = {}
    data["now_server"] = self.m_sNowServer
    data["born_server"] = self.m_sBornServer
    data["grade"] = self.m_iGrade
    data["name"] = self.m_sName
    data["school"] = self.m_iSchool
    data["score"] = self.m_iScore   --评分
    data["achieve"] = self.m_iAchieve --成就
    data["position"] = self.m_sPosition --地理位置
    data["position_hide"] = self.m_iPositionHide --隐藏位置
    data["model_info"] = self.m_mModelInfo
    data["icon"] = self.m_iIcon

    data["GoldCoin"] = self.m_iGoldCoin or 0
    data["RplGoldCoin"]  = self.m_iRplGoldCoin or 0

    local mUpvote = {}
    for pid, timestamp in pairs(self.m_mUpvote) do
        table.insert(mUpvote, {pid = pid, timestamp = timestamp})
    end
    data["upvote"] = mUpvote
    local mUpvoteReward = {}
    for idx , mInfo in pairs(self.m_mUpvoteReward) do
        mUpvoteReward[db_key(idx)] = mInfo
    end
    data["upvote_reward"] = mUpvoteReward
    data["title_info"] = self.m_mTitleInfo
    data["frozen_session"] = self.m_iFrozenSession
    data["frozen_money"] = self.m_mFrozenMoney
    data["show_id"] = self.m_iShowId
    data["touxian_info"] = self.m_mTouxianInfo
    data["role_type"] = self.m_iRoleType or 0
    data["couple_pid"] = self.m_iCouplePid or 0
    data["todaymorning"] = self.m_mTodayMorning

    data["ip"] = self.m_sIP
    data["mac"] = self.m_sMac
    data["device"] = self.m_sDevice
    data["plat"] = self.m_iPlatform
    data["account"] = self.m_sAccount
    data["channel"] = self.m_iChannel
    data["cps_channel"] = self.m_sCpsChannel
    data["udid"] = self.m_sUDID
    data["goldcoin_owe"] = self.m_iGoldCoinOwe
    data["truegoldcoin_owe"] = self.m_iTrueGoldCoinOwe
    data["last_online_time"] = self.m_iLastOnlineTime
    return data
end

function CProfileCtrl:Load(data)
    data = data or {}
    self.m_sNowServer = data["now_server"] or get_server_tag()
    self.m_sBornServer = data["born_server"] or get_server_tag()
    self.m_iGrade = data["grade"] or 0
    self.m_sName = data["name"] or ""
    self.m_iSchool = data["school"] or 0
    self.m_iScore = data["score"] or 0
    self.m_iAchieve = data["achieve"] or 0
    self.m_sPosition = data["position"] or ""
    self.m_iPositionHide = data["position_hide"]
    self.m_mModelInfo = data["model_info"] or {}
    self.m_iIcon = data["icon"] or 0

    self.m_iGoldCoin = data["GoldCoin"] or 0
    self.m_iRplGoldCoin = data["RplGoldCoin"] or 0

    local mUpvote = {}
     for _, mVote in pairs(data["upvote"] or {}) do
        mUpvote[mVote.pid] = mVote.timestamp
    end
    self.m_mUpvote = mUpvote
    self.m_mTitleInfo = data["title_info"] or {}

    local mUpvoteReward=data["upvote_reward"] or {}
    for sID,mInfo in pairs(mUpvoteReward) do
        self.m_mUpvoteReward[tonumber(sID)] = mInfo
    end

    self.m_iFrozenSession = data["frozen_session"] or 0
    self.m_mFrozenMoney = data["frozen_money"] or {}
    self.m_iShowId = data["show_id"] or self:GetPid()
    self.m_mTouxianInfo = data["touxian_info"] or {}
    self.m_iRoleType = data["role_type"] or 0
    self.m_iCouplePid = data["couple_pid"] or 0
    self.m_mTodayMorning = data["todaymorning"] or self.m_mTodayMorning

    self.m_sIP = data["ip"] or self.m_sIP
    self.m_sMac = data["mac"] or self.m_sMac
    self.m_sDevice = data["device"] or self.m_sDevice
    self.m_iPlatform = data["plat"] or self.m_iPlatform
    self.m_sAccount = data["account"] or self.m_sAccount
    self.m_iChannel = data["channel"] or self.m_iChannel
    self.m_sCpsChannel = data["cps_channel"] or self.m_sCpsChannel
    self.m_sUDID = data["udid"] or self.m_sUDID
    self.m_iGoldCoinOwe = data["goldcoin_owe"]  or 0
    self.m_iTrueGoldCoinOwe = data["truegoldcoin_owe"] or 0
    self.m_iLastOnlineTime = data["last_online_time"] or 0
end

function CProfileCtrl:OnLogin(oPlayer, bReEnter)
    self:Dirty()
    self.m_sNowServer = oPlayer:GetNowServer()
    self.m_sBornServer = oPlayer:GetBornServer()
    self.m_iGrade = oPlayer:GetGrade()
    self.m_sName = oPlayer:GetName()
    self.m_iSchool = oPlayer:GetSchool()
    self.m_iScore = oPlayer:GetScore()
    self.m_iAchieve = oPlayer:GetAchieve()
    self.m_sPosition = oPlayer:GetPosition()
    self.m_iPositionHide = oPlayer:GetPositionHide()
    self.m_mModelInfo = oPlayer:GetModelInfo()
    self.m_iIcon = oPlayer:GetIcon()
    if oPlayer.m_oTouxianCtrl.m_oTouxian then
        self.m_mTouxianInfo = oPlayer.m_oTouxianCtrl.m_oTouxian:PackNetInfo()
    end
    self.m_iLastOnlineTime = get_time()
end

function CProfileCtrl:GetBornServer()
    return self.m_sBornServer
end

function CProfileCtrl:GetBornServerKey()
    if self.m_sBornServer then
        return make_server_key(self.m_sBornServer)
    end
end

function CProfileCtrl:GetNowServer()
    return self.m_sNowServer
end

function CProfileCtrl:PackSimpleInfo()
    local mNet = {}
    mNet.pid = self:GetPid()
    mNet.name = self:GetName()
    mNet.grade = self:GetGrade()
    mNet.school = self:GetSchool()
    mNet.icon = self:GetIcon()
    return mNet
end

function CProfileCtrl:PackTouxianInfo()
    return self.m_mTouxianInfo
end

function CProfileCtrl:GetScore()
    return self.m_iScore
end

function CProfileCtrl:GetAchieve()
    return self.m_iAchieve
end

function CProfileCtrl:GetPosition()
    return self.m_sPosition
end

function CProfileCtrl:GetPositionHide()
    return self.m_iPositionHide
end

function CProfileCtrl:GetIcon()
    return self.m_iIcon
end

function CProfileCtrl:GetName()
    return self.m_sName
end

function CProfileCtrl:SetName(sName)
    self:Dirty()
    self.m_sName = sName
end

function CProfileCtrl:GetGrade()
    return self.m_iGrade
end

function CProfileCtrl:GetSchool()
    return self.m_iSchool
end

function CProfileCtrl:GetModelInfo()
    return self.m_mModelInfo
end

function CProfileCtrl:GetIcon()
    return self.m_iIcon
end

function CProfileCtrl:GetShowId()
    return self.m_iShowId
end

function CProfileCtrl:SetShowId(iNewShowId)
    self.m_iShowId = iNewShowId
    self:Dirty()
end

function CProfileCtrl:GetRoleType()
    return self.m_iRoleType
end

function CProfileCtrl:OnLogout(oPlayer)
    if oPlayer then
        self:Dirty()
        self.m_sNowServer = oPlayer:GetNowServer()
        self.m_sBornServer = oPlayer:GetBornServer()
        self.m_iGrade = oPlayer:GetGrade()
        self.m_sName = oPlayer:GetName()
        self.m_iSchool = oPlayer:GetSchool()
        self.m_iScore = oPlayer:GetScore()
        self.m_iAchieve = oPlayer:GetAchieve()
        self.m_sPosition = oPlayer:GetPosition()
        self.m_iPositionHide = oPlayer:GetPositionHide()
        self.m_mModelInfo = oPlayer:GetModelInfo()
        self.m_mTitleInfo = oPlayer:GetTitleInfo() or {}
        self.m_iIcon = oPlayer:GetIcon()
        self.m_iRoleType = oPlayer:GetRoleType()
        if oPlayer.m_oTouxianCtrl.m_oTouxian then
            self.m_mTouxianInfo = oPlayer.m_oTouxianCtrl.m_oTouxian:PackNetInfo()
        end

        -- 一些log信息
        self.m_sIP = oPlayer:GetIP()
        self.m_sMac = oPlayer:GetMac()
        self.m_sDevice = oPlayer:GetDevice()
        self.m_iPlatform = oPlayer:GetPlatform()
        self.m_sAccount = oPlayer:GetAccount()
        self.m_iChannel = oPlayer:GetChannel()
        self.m_sCpsChannel = oPlayer:GetCpsChannel()
        self.m_sUDID = oPlayer:GetUDID()
        self.m_iLastOnlineTime = get_time()
    end
    super(CProfileCtrl).OnLogout(self, oPlayer)
end

function CProfileCtrl:GetOrg()
    local oOrgMgr = global.oOrgMgr
    local iOrgID = self:GetOrgID()
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    return oOrg
end

function CProfileCtrl:GetOrgID()
    local iOrgID = global.oOrgMgr:GetPlayerOrgId(self:GetPid())
    return iOrgID or 0
end

function CProfileCtrl:GetOrgName()
    local oOrg = self:GetOrg()
    if oOrg then
        return oOrg:GetName()
    else
        return ""
    end
end

function CProfileCtrl:GetOrgPos()
    local oOrg = self:GetOrg()
    if oOrg then
        return oOrg:GetPosition(self:GetPid())
    end
    return 0
end

function CProfileCtrl:GetUpvote()
    return self.m_mUpvote
end

function CProfileCtrl:GetUpvoteAmount()
    return extend.Table.size(self.m_mUpvote)
end

function CProfileCtrl:GetUpvoteList()
    local lResult = {}
    for k, v in pairs(self.m_mUpvote) do
        table.insert(lResult, {k, v})
    end
    return lResult
end

function CProfileCtrl:AddUpvote(pid)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local otherPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if self.m_mUpvote[pid] then
        if otherPlayer then
            otherPlayer:Send("GS2CUpvotePlayer", {succuss = 0})
            oNotifyMgr:Notify(pid, "同一名玩家只能点赞一次！")
        end
        return
    end
    self.m_mUpvote[pid] = get_time()
    self:Dirty()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:PropChange("upvote_amount")
    end
    if otherPlayer then
        otherPlayer:Send("GS2CUpvotePlayer", {succuss = 1})
        if self:GetPid() == pid then
            oNotifyMgr:Notify(pid, "感觉自己萌萌哒是可以的，但下不为例哦")
        else
            oNotifyMgr:Notify(pid, "点赞成功！")
        end
    end

    local oRankMgr = global.oRankMgr
    oRankMgr:PushDataToUpvoteRank(self)
    local mLogData = self:LogData()
    mLogData["upvote_player"] = pid
    mLogData["upvote_amount"] = self:GetUpvoteAmount()
    record.log_db("player", "upvote", mLogData)
end

function CProfileCtrl:GetUpvoteRewardInfo(idx)
    local res = require "base.res"
    local mRewardInfo = res["daobiao"]["upvote"]
    return mRewardInfo[idx]
end

function CProfileCtrl:PacketAllUpvoteReward()
    local mNet, mData = {}, {}
    for idx, iFlag in pairs(self.m_mUpvoteReward) do
        local mTmp = {}
        mTmp.idx = idx
        mTmp.success = iFlag > 0 and 1 or 0
        table.insert(mData, mTmp)
    end
    mNet.info = mData
    return mNet
end

function CProfileCtrl:ValidGetUpvoteReward(oPlayer, idx)
    local mReward = self:GetUpvoteRewardInfo(idx)
    if not mReward then
        return false
    end
    if self.m_mUpvoteReward[idx] then
        return false
    end
    if self:GetUpvoteAmount() + oPlayer:Query("testman", 0) < mReward.upvote then
        return false
    end
    return true
end

function CProfileCtrl:C2GSUpvoteReward(idx)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    if not idx or idx==0 then
        local mNet = self:PacketAllUpvoteReward()
        oPlayer:Send("GS2CAllUpvoteReward", mNet)
    end

    local mNet = {}
    if not self:ValidGetUpvoteReward(oPlayer, idx) then
        mNet.info = {idx=idx, success=0}
    else
        local mReward = self:GetUpvoteRewardInfo(idx)

        local sReason = string.format("点赞_%d", idx)
        local iItemId = mReward.itemid
        if iItemId then
            local oItem = global.oItemLoader:ExtCreate(iItemId)
            oPlayer:RewardItem(oItem, sReason)
        end

        local iTitle = mReward.titleid
        if iTitle then
            global.oTitleMgr:AddTitle(self:GetPid(), iTitle)
        end

        self.m_mUpvoteReward[idx] = get_time()
        self:Dirty()
        mNet.info = {idx=idx, success=1}
    end

    oPlayer:Send("GS2CUpvoteReward", mNet)
end

function CProfileCtrl:DispatchFrozenSession()
    local iSession = self.m_iFrozenSession
    iSession = iSession + 1
    if iSession > 0x0fffffff then
        iSession = 1
    end
    self.m_iFrozenSession = iSession
    self:Dirty()
end

function CProfileCtrl:FrozenMoney(iType, iVal, sReason, iTime)
    local mFrozen = self.m_mFrozenMoney
    local sSession = db_key(self:DispatchFrozenSession())
    iTime = iTime or -1
    mFrozen[sSession] = {iType, iVal, sReason, iTime}
    self:Dirty()
    self:RefreshFrozenMoney(iType)

    local mLogData = self:LogData()
    mLogData["type"] = iType
    mLogData["frozen_add"] = iVal
    mLogData["frozen_now"] = self:GetFrozenMoney(iType)
    mLogData["reason"] = sReason
    mLogData["session"] = sSession
    record.log_db("money", "frozen_money", mLogData)

    return sSession
end

function CProfileCtrl:UnFrozenMoney(sSession)
    local mFrozen = self.m_mFrozenMoney
    if not mFrozen[sSession] then
        return
    end
    local mData = mFrozen[sSession]
    mFrozen[sSession] = nil
    self:Dirty()
    local iType = table.unpack(mData)
    self:RefreshFrozenMoney(iType)

    local mLogData = self:LogData()
    mLogData["type"] = iType
    mLogData["frozen_sub"] = mData[2]
    mLogData["frozen_now"] = self:GetFrozenMoney(iType)
    mLogData["reason"] = mData[3]
    mLogData["session"] = sSession
    record.log_db("money", "unfrozen_money", mLogData)
end

function CProfileCtrl:GetFrozenMoney(iType)
    self:CheckUnFrozenMoney()

    local iTotal = 0
    for sSession, mData in pairs(self.m_mFrozenMoney) do
        local iMoneyType, iVal = table.unpack(mData)
        if iMoneyType == iType then
            iTotal = iTotal + iVal
        end
    end
    return iTotal
end

function CProfileCtrl:CheckUnFrozenMoney()
    local lUnFrozen = {}
    local iCurr = get_time()
    for sSession, mData in pairs(self.m_mFrozenMoney) do
        local iMoneyType, iVal, sReason, iTime = table.unpack(mData)
        if iTime > 0 and iCurr <= iTime then
            table.insert(lUnFrozen, sSession)
        end
    end
    for _, sSession in ipairs(lUnFrozen) do
        self:UnFrozenMoney(sSession)
    end
end

function CProfileCtrl:_CheckSelf()
    self:CheckUnFrozenMoney()
end

function CProfileCtrl:RefreshFrozenMoney(iType)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        if iType == gamedefines.MONEY_TYPE.GOLDCOIN then
            oPlayer:PropChange("goldcoin")
        elseif iType == gamedefines.MONEY_TYPE.GOLD then
            oPlayer:PropChange("gold")
        elseif iType == gamedefines.MONEY_TYPE.SILVER then
            oPlayer:PropChange("silver")
        elseif iType == gamedefines.MONEY_TYPE.RPLGOLD then
            oPlayer:PropChange("rplgoldcoin")
        end
    end
end

function CProfileCtrl:ChargeGold(iGoldCoin, sReason, mArgs)
    self:AddGoldCoin(iGoldCoin, sReason, mArgs)
end

function CProfileCtrl:AddGoldCoin(iGoldCoin,sReason, mArgs)
    self:Dirty()
    mArgs = mArgs or {}
    local mLogData = self:LogGoldCoinData()
    mLogData["rplgoldcoin_old"] = nil
    
    assert(iGoldCoin>0,string.format("%d AddGoldCoin err %d %d",self:GetPid(),self.m_iGoldCoin,iGoldCoin))
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local iOldGoldCoin = self.m_iGoldCoin
    local iOldTrueGoldCoinOwe = self:TrueGoldCoinOwe()
    local iOldGoldCoinOwe = self:GoldCoinOwe()
    local sMsg = oToolMgr:FormatColorString("获得#goldcoin#cur_1",  {goldcoin = iGoldCoin})

    local iTruePayBack = math.min(iGoldCoin,self.m_iTrueGoldCoinOwe)
    local iAddGold = iGoldCoin - iTruePayBack
    self.m_iTrueGoldCoinOwe = self.m_iTrueGoldCoinOwe - iTruePayBack

    local iPayBack = math.min(iAddGold,self.m_iGoldCoinOwe)
    iAddGold = iAddGold - iPayBack
    self.m_iGoldCoinOwe = self.m_iGoldCoinOwe - iPayBack

    self.m_iGoldCoin  = self.m_iGoldCoin + iAddGold
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        self:AddSaveMerge(oPlayer)
        if not mArgs.cancel_tip then
            oPlayer:NotifyMessage(sMsg)
        end
        if iTruePayBack>0 then
            if self.m_iTrueGoldCoinOwe > 0 then
                local sText = oToolMgr:GetTextData(1011,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iTruePayBack, self.m_iTrueGoldCoinOwe}})
            elseif self.m_iTrueGoldCoinOwe ==0 then
                local sText = oToolMgr:GetTextData(1012,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iTruePayBack}})
            end
        end
        if iPayBack>0 then
            if self.m_iGoldCoinOwe > 0 then
                local sText = oToolMgr:GetTextData(1017,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iPayBack, self.m_iGoldCoinOwe}})
            elseif self.m_iGoldCoinOwe ==0 then
                local sText = oToolMgr:GetTextData(1018,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iPayBack}})
            end
        end
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:PropChange("goldcoin")
    end

    mLogData["reason"] = sReason
    mLogData["goldcoin_add"] = iGoldCoin
    mLogData["goldcoin_now"] = self:TrueGoldCoin()
    mLogData["goldcoin_owe_now"] = self:GoldCoinOwe()
    mLogData["goldcoin_owe_old"] = iOldGoldCoinOwe
    mLogData["truegoldcoin_owe_now"] = self:TrueGoldCoinOwe()
    mLogData["truegoldcoin_owe_old"] = iOldTrueGoldCoinOwe
    record.log_db("money", "add_goldcoin", mLogData)

    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.GOLDCOIN, iGoldCoin, iOldGoldCoin, sReason)
end

function  CProfileCtrl:AddRplGoldCoin(iRplGold, sReason, mArgs)
    self:Dirty()
    local mLogData = self:LogGoldCoinData()
    mLogData["goldcoin_old"] = nil

    local iOldRplGoldCoin = self.m_iRplGoldCoin
    assert(iRplGold>0,string.format("%d AddRplGoldCoin err %d %d",self:GetPid(),self.m_iRplGoldCoin,iRplGold))
    local iOldGoldCoinOwe = self:GoldCoinOwe()
    local iPayBack = math.min(iRplGold,self.m_iGoldCoinOwe)
    local iAddRplGold = iRplGold - iPayBack
    self.m_iRplGoldCoin = self.m_iRplGoldCoin + iAddRplGold
    self.m_iGoldCoinOwe = self.m_iGoldCoinOwe - iPayBack
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not mArgs then
        mArgs = {}
    end
    if oPlayer then
        self:AddSaveMerge(oPlayer)
        local sMsg = oToolMgr:FormatColorString("获得#goldcoin#cur_2", {goldcoin = iRplGold})
        if not mArgs.cancel_tip then
            oPlayer:NotifyMessage(sMsg)
        end
        if iPayBack>0 then
            if self.m_iGoldCoinOwe > 0 then
                local sText = oToolMgr:GetTextData(1017,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iPayBack, self.m_iGoldCoinOwe}})
            elseif self.m_iGoldCoinOwe ==0 then
                local sText = oToolMgr:GetTextData(1018,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {goldcoin = {iPayBack}})
            end
        end
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:PropChange("rplgoldcoin","goldcoin_owe")
    end

    mLogData["reason"] = sReason
    mLogData["rplgoldcoin_add"] = iRplGold
    mLogData["rplgoldcoin_now"] = self:RplGoldCoin()
    mLogData["goldcoin_owe_now"] = self:GoldCoinOwe()
    mLogData["goldcoin_owe_old"] = iOldGoldCoinOwe
    record.log_db("money", "add_rplgoldcoin", mLogData)

    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.RPLGOLD, iRplGold, iOldRplGoldCoin, sReason)
end

function CProfileCtrl:GoldCoin()
    return self:TrueGoldCoin() + self:RplGoldCoin()
end

function CProfileCtrl:TrueGoldCoin()
    local iFrozen = self:GetFrozenMoney(gamedefines.MONEY_TYPE.GOLDCOIN)
    return math.max(0, self.m_iGoldCoin - iFrozen)
end

function CProfileCtrl:RplGoldCoin()
    local iFrozen = self:GetFrozenMoney(gamedefines.MONEY_TYPE.RPLGOLD)
    return math.max(0, self.m_iRplGoldCoin - iFrozen)
end

function CProfileCtrl:GoldCoinOwe()
    return self.m_iGoldCoinOwe
end

function CProfileCtrl:TrueGoldCoinOwe()
    return self.m_iTrueGoldCoinOwe
end

function CProfileCtrl:CleanGoldCoinOwe()
    self:Dirty()
    self.m_iGoldCoinOwe = 0 
end

function CProfileCtrl:CleanTrueGoldCoinOwe()
    self:Dirty()
    self.m_iTrueGoldCoinOwe = 0 
end

function CProfileCtrl:FrozenGoldCoin(iVal, sReason, iTime)
    local iRplGoldCoin = self:RplGoldCoin()
    local lResult = {}
    if iVal <= iRplGoldCoin then
        table.insert(lResult, self:FrozenMoney(gamedefines.MONEY_TYPE.RPLGOLD, iVal, sReason, iTime))
    else
        table.insert(lResult, self:FrozenMoney(gamedefines.MONEY_TYPE.RPLGOLD, iRplGoldCoin, sReason, iTime))
        table.insert(lResult, self:FrozenMoney(gamedefines.MONEY_TYPE.GOLDCOIN, iVal-iRplGoldCoin, sReason, iTime))
    end
    return lResult
end

function CProfileCtrl:ValidGoldCoin(iGold,mArgs)
    mArgs = mArgs or {}
    local iSumGold = self:GoldCoin()
    if iSumGold >= iGold then
        return true
    end
    local sTip = mArgs.tip
    if not sTip then
        sTip = "元宝不足"
    end
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(self:GetPid(),sTip)
    local bShort = mArgs.short
    if not bShort then
        local oUIMgr = global.oUIMgr
        oUIMgr:GS2CShortWay(self:GetPid(),1)
    end
    return false
end

-- 优先绑定
function CProfileCtrl:ResumeGoldCoin(iVal,sReason,mArgs)
    assert(iVal > 0, string.format("%s resume goldcoin err %d",sReason, iVal))
    self:Dirty()
    mArgs = mArgs or {}
    local mCostRecord = {}
    mCostRecord["iCoin"] = 0
    mCostRecord["iRplCoin"] = 0

    local mLogData = self:LogGoldCoinData()
    local iOldGc, iOldRp = self.m_iGoldCoin, self.m_iRplGoldCoin
    local iOldGoldCoinOwe = self:GoldCoinOwe()
    local iOldTrueGoldCoinOwe = self:TrueGoldCoinOwe()

    if self.m_iRplGoldCoin >= iVal then
        mCostRecord.iRplCoin = iVal
        self.m_iRplGoldCoin = self.m_iRplGoldCoin - iVal
    else
        mCostRecord.iRplCoin = self.m_iRplGoldCoin
        local iCostCoinVal = iVal -  mCostRecord.iRplCoin
        self.m_iRplGoldCoin = 0
        mCostRecord.iCoin = iCostCoinVal
        self.m_iGoldCoin = self.m_iGoldCoin - iCostCoinVal
        if self.m_iGoldCoin<0 then
            self.m_iGoldCoinOwe = self.m_iGoldCoinOwe - self.m_iGoldCoin
            self.m_iGoldCoin = 0
        end
    end
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        local sMsg
        if mCostRecord.iRplCoin > 0 and mCostRecord.iCoin > 0 then
            sMsg = oToolMgr:FormatColorString("消耗#G#rplgoldcoin#n#cur_2，#G#truegoldcoin#cur_1", {rplgoldcoin = mCostRecord.iRplCoin, truegoldcoin = mCostRecord.iCoin})
        elseif mCostRecord.iRplCoin > 0 then
            sMsg = oToolMgr:FormatColorString("消耗#G#rplgoldcoin#cur_2", {rplgoldcoin = mCostRecord.iRplCoin})
        else
            sMsg = oToolMgr:FormatColorString("消耗#G#truegoldcoin#cur_1",{truegoldcoin = mCostRecord.iCoin})
        end
        local oChatMgr = global.oChatMgr
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:PropChange("goldcoin", "rplgoldcoin","goldcoin_owe")
        if not mArgs.cancel_rank then
            oPlayer.m_oTodayMorning:Add("today_expense_goldcoin",mCostRecord.iCoin)
        end
        self:OnResumeTrueGoldCoin(oPlayer)
    end

    mLogData["goldcoin_now"] = self:TrueGoldCoin()
    mLogData["goldcoin_sub"] = mCostRecord["iCoin"]
    mLogData["rplgoldcoin_now"] = self:RplGoldCoin()
    mLogData["rplgoldcoin_sub"] = mCostRecord["iRplCoin"]
    mLogData["goldcoin_owe_now"] = self:GoldCoinOwe()
    mLogData["goldcoin_owe_old"] = iOldGoldCoinOwe
    mLogData["truegoldcoin_owe_now"] = self:TrueGoldCoinOwe()
    mLogData["truegoldcoin_owe_old"] = iOldTrueGoldCoinOwe
    mLogData["reason"] = sReason
    mLogData["subreason"] = mArgs.subreason or ""
    record.log_db("money", "sub_goldcoin", mLogData)

    if iOldGc > self.m_iGoldCoin then
        self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.GOLDCOIN, self.m_iGoldCoin-iOldGc, iOldGc, sReason)
        if not mArgs.cancel_rank and oPlayer then
            global.oRankMgr:PushDataToEveryDayRank(oPlayer, "resume_goldcoin", {cnt=iOldGc-self.m_iGoldCoin})
        end
    end
    if iOldRp > self.m_iRplGoldCoin then
        self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.RPLGOLD, self.m_iRplGoldCoin-iOldRp, iOldRp, sReason)
    end
    return mCostRecord
end

function CProfileCtrl:OnResumeTrueGoldCoin(oPlayer)
        oPlayer:TriggerEvent(gamedefines.EVENT.PLAYER_RESUME_TRUEGOLDCOIN, {player = oPlayer })
end

function CProfileCtrl:ValidTrueGoldCoin(iGold, mArgs)
    mArgs = mArgs or {}
    local iTrueGold = self:TrueGoldCoin()
    if iTrueGold >= iGold then
        return true
    end
    local sTip = mArgs.tip
    if not sTip then
        sTip = "非绑定元宝不足"
    end
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(self:GetPid(), sTip)
    local bShort = mArgs.short
    if not bShort then
        local oUIMgr = global.oUIMgr
        oUIMgr:GS2CShortWay(self:GetPid(), 1)
    end
    return false
end

function CProfileCtrl:ResumeTrueGoldCoin(iVal, sReason, mArgs)
    assert(iVal > 0, string.format("%s resume truegoldcoin err %d",sReason, iVal))
    self:Dirty()
    mArgs = mArgs or {}
    local mLogData = self:LogGoldCoinData()
    local iOldGc = self.m_iGoldCoin
    local iOldGoldCoinOwe = self:GoldCoinOwe()
    local iOldTrueGoldCoinOwe = self:TrueGoldCoinOwe()
    self.m_iGoldCoin = self.m_iGoldCoin - iVal
    if self.m_iGoldCoin<0 then
        self.m_iTrueGoldCoinOwe = self.m_iTrueGoldCoinOwe - self.m_iGoldCoin
        self.m_iGoldCoin = 0
    end

    local iPid = self:GetPid()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local oToolMgr = global.oToolMgr
        local sMsg = oToolMgr:FormatColorString("消耗#G#goldcoin#n#cur_1", {goldcoin = iVal})
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:PropChange("goldcoin","truegoldcoin_owe")
        if not mArgs.cancel_rank then
            oPlayer.m_oTodayMorning:Add("today_expense_goldcoin",iVal)
            self:OnResumeTrueGoldCoin(oPlayer)
        end
    end


    mLogData["goldcoin_now"] = self:TrueGoldCoin()
    mLogData["goldcoin_sub"] = iVal
    mLogData["rplgoldcoin_now"] = self:RplGoldCoin()
    mLogData["rplgoldcoin_sub"] = 0
    mLogData["goldcoin_owe_now"] = self:GoldCoinOwe()
    mLogData["goldcoin_owe_old"] = iOldGoldCoinOwe
    mLogData["truegoldcoin_owe_now"] = self:TrueGoldCoinOwe()
    mLogData["truegoldcoin_owe_old"] = iOldTrueGoldCoinOwe
    mLogData["reason"] = sReason
    mLogData["subreason"] = mArgs.subreason or ""
    record.log_db("money", "sub_goldcoin", mLogData)

    if iOldGc > self.m_iGoldCoin then
        self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.GOLDCOIN, self.m_iGoldCoin-iOldGc, iOldGc, sReason)
        if not mArgs.cancel_rank and oPlayer then
            global.oRankMgr:PushDataToEveryDayRank(oPlayer, "resume_goldcoin", {cnt=iVal})
        end
    end
end

function CProfileCtrl:ValidRplGoldCoin(iGold, mArgs)
    mArgs = mArgs or {}
    local iRplGold = self:RplGoldCoin()
    if iRplGold >= iGold then
        return true
    end
    local sTip = mArgs.tip
    if not sTip then
        sTip = "绑定元宝不足"
    end
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(self:GetPid(), sTip)
    -- 绑定元宝先不弹充值界面
    -- local bShort = mArgs.short
    -- if not bShort then
    --     local oUIMgr = global.oUIMgr
    --     oUIMgr:GS2CShortWay(self:GetPid(), 1)
    -- end
    return false
end

function CProfileCtrl:ResumeRplGoldCoin(iVal, sReason, mArgs)
    assert(iVal > 0, string.format("%s resume rplgoldcoin err %d", sReason, iVal))
    self:Dirty()
    mArgs = mArgs or {}
    local mLogData = self:LogGoldCoinData()
    local iOldRp = self.m_iRplGoldCoin
    local iOldGoldCoinOwe = self:GoldCoinOwe()
    local iOldTrueGoldCoinOwe = self:TrueGoldCoinOwe()

    self.m_iRplGoldCoin = self.m_iRplGoldCoin - iVal
    if self.m_iRplGoldCoin < 0 then
        -- 普通元宝欠费和非绑定元宝欠费为平行关系（非包含）
        self.m_iGoldCoinOwe = self.m_iGoldCoinOwe - self.m_iRplGoldCoin
        self.m_iRplGoldCoin = 0
    end

    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        local sMsg = oToolMgr:FormatColorString("消耗#G#rplgoldcoin#cur_2", {rplgoldcoin = iVal})
        local oChatMgr = global.oChatMgr
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:PropChange("rplgoldcoin", "goldcoin_owe")
        -- 非绑定元宝消费不计入排行榜
    end
    mLogData["goldcoin_now"] = self:TrueGoldCoin()
    mLogData["goldcoin_sub"] = 0
    mLogData["rplgoldcoin_now"] = self:RplGoldCoin()
    mLogData["rplgoldcoin_sub"] = iVal
    mLogData["goldcoin_owe_now"] = self:GoldCoinOwe()
    mLogData["goldcoin_owe_old"] = iOldGoldCoinOwe
    mLogData["truegoldcoin_owe_now"] = self:TrueGoldCoinOwe()
    mLogData["truegoldcoin_owe_old"] = iOldTrueGoldCoinOwe
    mLogData["reason"] = sReason
    mLogData["subreason"] = mArgs.subreason or ""
    record.log_db("money", "sub_goldcoin", mLogData)

    if iOldRp > self.m_iRplGoldCoin then
        self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.RPLGOLD, self.m_iRplGoldCoin-iOldRp, iOldRp, sReason)
    end
end

function CProfileCtrl:SetTitleInfo(mTitInfo)
    if not mTitInfo then return end
    self:Dirty()
    self.m_mTitleInfo.tid = mTitInfo.tid
    self.m_mTitleInfo.name = mTitInfo.name
    self.m_mTitleInfo.achieve_time = mTitInfo.achieve_time
end

function CProfileCtrl:ClearTitleInfo()
    self:Dirty()
    self.m_mTitleInfo = {}
end

function CProfileCtrl:GetTitleInfo()
    return self.m_mTitleInfo
end

function CProfileCtrl:PackTitleInfo()
    local mNet = {}
    mNet.tid = self.m_mTitleInfo.tid
    mNet.name = self.m_mTitleInfo.name
    mNet.achieve_time = self.m_mTitleInfo.achieve_time
    return mNet
end

function CProfileCtrl:GetCouplePid()
    return self.m_iCouplePid
end

function CProfileCtrl:PackBackendInfo()
    return {
        profile_info = {GoldCoin=self:TrueGoldCoin(), RplGoldCoin=self:RplGoldCoin()},
    }
end

function CProfileCtrl:LogData()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetPid()
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        return oPlayer:LogData()
    else
        return {pid=self:GetPid(), show_id=self:GetShowId(), name=self:GetName(), grade=self:GetGrade(), channel=""}
    end
end

function CProfileCtrl:LogGoldCoinData()
    local mLogData = self:LogData()
    mLogData["goldcoin_old"] = self:TrueGoldCoin()
    mLogData["rplgoldcoin_old"] = self:RplGoldCoin()
    return mLogData
end

function CProfileCtrl:GetAccount()
    return self.m_sAccount
end

function CProfileCtrl:GetIP()
    return self.m_sIP
end

function CProfileCtrl:GetDevice()
    return self.m_sDevice
end

function CProfileCtrl:GetMac()
    return self.m_sMac
end

function CProfileCtrl:GetUDID()
    return self.m_sUDID
end

function CProfileCtrl:GetChannel()
    return self.m_iChannel
end

function CProfileCtrl:GetCpsChannel()
    return self.m_sCpsChannel
end

function CProfileCtrl:GetPlatform()
    return self.m_iPlatform
end

function CProfileCtrl:BaseAnalyInfo()
    return {
        account_id = self:GetAccount(),
        role_id = self:GetPid(),
        role_name = self:GetName(),
        profession = self:GetSchool(),
        role_level = self:GetGrade(),
        fight_point = self:GetScore(),
        ip = self:GetIP(),
        device_model = self:GetDevice(),
        udid = self:GetUDID(),
        os = "",
        version = "",
        app_channel = self:GetChannel(),
        sub_channel = self:GetCpsChannel(),
        server = self:GetBornServerKey(),
        plat = self:GetPlatform()
    }
end

function CProfileCtrl:LogAnalyInfo(oPlayer, sMoneyType, iVal, iOldVal, sReason)
    -- 数据中心log
    local iNowVal, sMtbi
    if sMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        iNowVal, sMtbi = self:TrueGoldCoin(), "goldcoin" 
    elseif sMoneyType == gamedefines.MONEY_TYPE.RPLGOLD then
        iNowVal, sMtbi = self:RplGoldCoin(), "rpgoldcoin"
    else
        return
    end

    local mAnalyLog = self:BaseAnalyInfo()
    mAnalyLog["currency_type"] = sMoneyType
    mAnalyLog["num"] = iVal
    mAnalyLog["remain_currency"] = iNowVal or 0
    mAnalyLog["reason"] = sReason
    analy.log_data("currency", mAnalyLog)
end

function CProfileCtrl:GetLastOnlineTime()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    return oPlayer and get_time() or self.m_iLastOnlineTime
end

function CProfileCtrl:SetTodayMorning(sKey, value)
    self:ValidTodayMorning(sKey)
    local mData = self.m_mTodayMorning["data"]
    if not mData then
        mData = {}
        self.m_mTodayMorning["data"] = mData
    end
    mData[sKey] = value
    self:Dirty()
end

function CProfileCtrl:QueryTodayMorning(sKey, rDefault)
    self:ValidTodayMorning(sKey)
    local mData = self.m_mTodayMorning["data"] or {}
    return mData[sKey] or rDefault
end

function CProfileCtrl:AddTodayMorning(sKey, value)
    self:ValidTodayMorning(sKey)
    local mData = self.m_mTodayMorning["data"]
    if not mData then
        mData = {}
        self.m_mTodayMorning["data"] = mData
    end
    mData[sKey] = value + (mData[sKey] or 0)
    self:Dirty()
end

function CProfileCtrl:ValidTodayMorning(sKey)
    local iDayNo = self.m_mTodayMorning["timeno"] or 0
    if iDayNo >= get_morningdayno() then return end

    self.m_mTodayMorning["timeno"] = get_morningdayno()
    self.m_mTodayMorning["data"] = nil
    self:Dirty()
end

function CProfileCtrl:RemoteKsEvent(mData, endfunc)
    local sFunc = mData.func
    local lArgs = mData.args 
    print("liuzla-deubug---CProfileCtrl:RemoteKsEvent---", sFunc, lArgs)
    self[sFunc](self, table.unpack(lArgs))

    endfunc({
        goldcoin = self.m_iGoldCoin,
        rplgoldcoin = self.m_iRplGoldCoin
    })
end




