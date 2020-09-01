--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local fmtobj = import(service_path("formation.fmtobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

function NewFmtMgr(iPid, ...)
    local o = CFmtMgr:New(iPid, ...)
    return o
end


CFmtMgr = {}
CFmtMgr.__index = CFmtMgr
inherit(CFmtMgr, datactrl.CDataCtrl)

function CFmtMgr:New(iPid, ...)
    local o = super(CFmtMgr).New(self)
    o:SetInfo("pid", iPid)
    o:Init()
    return o
end

function CFmtMgr:Init()
    self.m_mFmtObj = {}
    self:AddNormalFmt()
end

function CFmtMgr:Release()
    for _, obj in pairs(self.m_mFmtObj) do
        baseobj_safe_release(obj)
    end
    super(CFmtMgr).Release(self)
end

function CFmtMgr:Save()
    local mFmtData = {}
    for iFmt, obj in pairs(self.m_mFmtObj) do
        mFmtData[db_key(iFmt)] = obj:Save()
    end
    
    local mData = {}
    mData.fmt_data = mFmtData
    mData.data = self.m_mData
    return mData
end

function CFmtMgr:Load(m)
    local iPid = self:GetOwner()
    local mFmtData = m.fmt_data or {}
    for sFmt, mUnit in pairs(mFmtData) do
        local iFmt = tonumber(sFmt)
        local obj = fmtobj.NewFmtObj(iPid, iFmt)
        obj:Load(mUnit)
        self.m_mFmtObj[iFmt] = obj
    end
    self.m_mData = m.data or {}
end

function CFmtMgr:IsDirty()
    local bIsDirty = super(CFmtMgr).IsDirty(self)
    if bIsDirty then return true end

    for iFmt, obj in pairs(self.m_mFmtObj) do
        if obj:IsDirty() then
            return true
        end
    end
end

function CFmtMgr:UnDirty()
    super(CFmtMgr).UnDirty(self)
    for iFmt, obj in pairs(self.m_mFmtObj) do
        obj:UnDirty()
    end
end

function CFmtMgr:AddNormalFmt()
    local iPid = self:GetOwner()
    local iFmt = 1
    local obj = fmtobj.NewFmtObj(iPid, iFmt)
    self.m_mFmtObj[iFmt] = obj
    self:SetData("curr_fmt", iFmt)
    global.oScoreCache:Dirty(self:GetOwner(), "fmt")

    local oPlayer = self:GetPlayer()
    if oPlayer then
        analylog.LogSystemInfo(oPlayer, "fmt_add", iFmt, {})
    end
end

function CFmtMgr:GetOwner()
    return self:GetInfo("pid")
end

function CFmtMgr:GetPlayer()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetOwner()
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CFmtMgr:GetFmtObj(iFmt)
    return self.m_mFmtObj[iFmt]
end

function CFmtMgr:AddFmtObj(iFmt, obj)
    self.m_mFmtObj[iFmt] = obj
    self:Dirty()
    global.oScoreCache:Dirty(self:GetOwner(), "fmt")

    local oPlayer = self:GetPlayer() 

    if table_count(self.m_mFmtObj) <= 2 then
        local lPosList = self:PackPosList() or {}
        self:SetFmtPosInfo(iFmt, lPosList)
    end
   
    local mLogData = oPlayer:LogData()
    mLogData["fmt_id"] = iFmt
    record.log_db("formation", "add_fmt", mLogData)

    analylog.LogSystemInfo(oPlayer, "fmt_add", iFmt, {})
end

function CFmtMgr:GetCurrFmtObj()
    local iFmt = self:GetCurrFmt()
    assert(iFmt>0 and iFmt<10, "illegal curr fmt")
    return self:GetFmtObj(iFmt)
end

function CFmtMgr:GetFmtSize()
    return table_count(self.m_mFmtObj)
end

function CFmtMgr:GetFmtLearnLimit()
    local mLimitConf = res["daobiao"]["formation"]["use_limit"]
    local oPlayer = self:GetPlayer()
    if not oPlayer then return 0 end
    local iGrade = oPlayer:GetGrade()
    local iLimit = 0
    for idx, mInfo in ipairs(mLimitConf) do
        if iGrade >= mInfo.grade then
            iLimit = mInfo.num
        else
            break
        end
    end
    local iFmtSize = self:GetFmtSize()
    return math.max(iLimit - iFmtSize, 0)
end

function CFmtMgr:GetGrade(iFmt)
    local oFmtObj = self:GetFmtObj(iFmt)
    return oFmtObj:GetGrade()
end

function CFmtMgr:GetName(iFmt)
    local oFmtObj = self:GetFmtObj(iFmt)
    return oFmtObj:GetName()
end


function CFmtMgr:FastUpgradeFmt(iFmt, lBookList)
    local iPid = self:GetOwner()
    local sMsg = string.format("%d fastupgrade, error fmt_id %d", iPid, iFmt)
    assert(iFmt > 1 and iFmt < 10, sMsg)
    local oPlayer = self:GetPlayer()
    local oFmtObj = self:GetFmtObj(iFmt)
    if not oFmtObj then return end
    local iBeforeLevel = oFmtObj:GetGrade()
    global.oItemHandler:ItemListUse(oPlayer, lBookList, iFmt, {})
    local iAfterLevel = oFmtObj:GetGrade()
    if iAfterLevel > iBeforeLevel then
        return
    end
    local iCurExp = oFmtObj:GetExp()
    local iNextExp = oFmtObj:GetNextExp()
    if not iNextExp or iNextExp <= 0 then
        return
    end
    local iMapBookSid = self:GetFmt2BookSid(iFmt)
    if not iMapBookSid then return end
    local oItem = global.oItemLoader:GetItem(iMapBookSid)
    local iAddExp = oItem:GetAddExp(iFmt)
    if not iAddExp or iAddExp <= 0 then return end
    local iAmount = math.ceil((iNextExp - iCurExp) / iAddExp)

    -- 不足不会再去检测背包内的阵法书，而是直接扣除元宝
    -- local lItemList = {}
    -- local sReason = "快捷阵法升级"
    -- local mCost = {}
    -- lItemList[iMapBookSid] = {amount = iAmount}
    -- local iExist, iNeedGoldCoin = global.oFastBuyMgr:GetFastBuyCost(oPlayer, lItemList, sReason)
    -- if not iExist then return end

    -- if iNeedGoldCoin <= 0 then return end
    -- if not oPlayer:ValidGoldCoin(iNeedGoldCoin) then return end
    -- oPlayer:ResumeGoldCoin(iNeedGoldCoin, sReason)
    -- mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = iNeedGoldCoin

    -- 不足不会再去检测背包内的阵法书，而是直接扣除元宝
    local mCost = {}
    local mNeedCost = {
        item = { [iMapBookSid] = iAmount }
    }
    local sReason = "快捷阵法升级"
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
    if not bSucc then return end
    if mTrueCost["goldcoin"] then
        mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
    end
    if mTrueCost["gold"] then
        mCost[gamedefines.MONEY_TYPE.GOLD] = mTrueCost["gold"]
    end

    self:AddExp(iFmt, iAddExp * iAmount)

    local mLogData = oPlayer:LogData()
    mLogData["fmt_id"] = iFmt
    mLogData["exp_add"] = iAddExp * iAmount
    mLogData["cost"] = mCost
    record.log_db("formation", "fmt_fastup", mLogData)
end

function CFmtMgr:GetFmt2BookSid(iFmt)
    local mData = res["daobiao"]["formation"]["fmt_booksid"]
    return mData[iFmt]
end

function CFmtMgr:AddExp(iFmt, iAdd)
    local iPid = self:GetOwner()
    local sMsg = string.format("%d add illegal fmt_id %d", iPid, iFmt)
    assert(iFmt>1 and iFmt<10, sMsg)

    local oFmtObj = self:GetFmtObj(iFmt)
    if oFmtObj then
        return oFmtObj:AddExp(iAdd)
    else
        local obj = fmtobj.NewFmtObj(self:GetOwner(), iFmt)
        self:AddFmtObj(iFmt, obj)
        self:RefreshOneFmtInfo(iFmt)
        self:Notify(iPid, 1002, {name=obj:GetName()})
        
        global.oScoreCache:Dirty(iPid, "fmt")
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:PropChange("score")
        end
        return true
    end
end

function CFmtMgr:BroadCastFmt2Team()
    local oPlayer = self:GetPlayer()
    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:BroadCastLeaderFmt()
    end
end

function CFmtMgr:SetCurrFmt(iFmt)
    assert(iFmt>0 and iFmt<10, string.format("%d get wrong fmt %d", self:GetOwner(), iFmt))
    iFmt = self:GetFmtObj(iFmt) and iFmt or 1
    local iOldFmt = self:GetCurrFmt()
    if iFmt == iOldFmt then return end

    self:SetData("curr_fmt", iFmt)
    local oPlayer = self:GetPlayer()
    oPlayer.m_oPartnerCtrl:SetCurrLineupFmt(iFmt)
    self:BroadCastFmt2Team()

    local mLogData = oPlayer:LogData()
    mLogData["fmt_old"] = iOldFmt
    mLogData["fmt_now"] = self:GetCurrFmt()
    record.log_db("formation", "fmt_set", mLogData)
end

function CFmtMgr:GetCurrFmt()
    return self:GetData("curr_fmt", 1)
end

function CFmtMgr:SetFmtPosInfo(iFmt, lPosList)
    assert(iFmt>0 and iFmt<10, "wrong fmt_id")
    if not self:GetFmtObj(iFmt) then
        self:Notify(self:GetOwner(), 1005)
        return
    end

    self:SetCurrFmt(iFmt)
    local oPlayer = self:GetPlayer()
    if oPlayer and oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        oTeam:SetFmtPosInfo(lPosList)
        oTeam:SyncSceneTeam(oPlayer)
        oTeam:BroadCastTeamAllPos()
    end
    self:RefreshFmtPos()
    --self:Notify(self:GetOwner(), 1001)
end

function CFmtMgr:PackWarFormationInfo(iPartnerLimit)
    local oFmtObj = self:GetCurrFmtObj()
    if not oFmtObj then return end

    iPartnerLimit = iPartnerLimit or 4
    local mResult = {}
    local lDefault = {oFmtObj:GetOwner()}
    local lPlayer = self:PackPosList() or lDefault
    local lPartner = self:GetCurrLineupPos() or {}
    if (math.min(#lPartner, iPartnerLimit) + #lPlayer) >= 5 then
        mResult.grade = oFmtObj:GetGrade()
        mResult.fmt_id = oFmtObj:GetInfo("fmt_id")
        mResult.pid = oFmtObj:GetOwner()
        mResult.player_list = lPlayer
        mResult.partner_list = lPartner
    else
        oFmtObj = self:GetFmtObj(1)
        mResult.grade = oFmtObj:GetGrade()
        mResult.fmt_id = oFmtObj:GetInfo("fmt_id")
        mResult.pid = oFmtObj:GetOwner()
        mResult.player_list = lPlayer
        mResult.partner_list = lPartner
    end
    return mResult
end

function CFmtMgr:PackSingleFmt(iFmt)
    local mResult = {}
    local obj = self:GetFmtObj(iFmt)
    mResult.fmt_id = obj:GetId()
    mResult.exp = obj:GetExp()
    mResult.grade = obj:GetGrade()
    return mResult
end

function CFmtMgr:PackAllFmt()
    local mResult = {}
    for iFmt, obj in pairs(self.m_mFmtObj) do
        local mTmp = self:PackSingleFmt(iFmt)
        table.insert(mResult, mTmp)
    end
    return mResult
end

function CFmtMgr:PackPosList()
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    if oPlayer:IsTeamLeader() then
        local oTeam = oPlayer:HasTeam()
        return oTeam:GetFmtPosList()
    end
end

function CFmtMgr:RefreshAllFmtInfo()
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local mNet = {}
        mNet.fmt_curr = self:GetCurrFmt()
        mNet.fmt_list = self:PackAllFmt()
        mNet.player_list = self:PackPosList()
        mNet.partner_list = self:GetCurrLineupPos()
        mNet.fmt_learn_limit = self:GetFmtLearnLimit()
        oPlayer:Send("GS2CAllFormationInfo", mNet)
    end
end

function CFmtMgr:RefreshOneFmtInfo(iFmt)
    local oPlayer = self:GetPlayer()
    if not oPlayer then return end

    local mNet = {}
    if self.m_mFmtObj[iFmt] then
        mNet.fmt_info = self:PackSingleFmt(iFmt)
    end
    mNet.fmt_learn_limit = self:GetFmtLearnLimit()
    oPlayer:Send("GS2CSingleFormationInfo", mNet)
end

function CFmtMgr:RefreshFmtPos()
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local mNet = {}
        mNet.fmt_curr = self:GetCurrFmt()
        mNet.player_list = self:PackPosList()
        mNet.partner_list = self:GetCurrLineupPos()
        oPlayer:Send("GS2CFmtPosInfo", mNet)
    end
end

function CFmtMgr:GetCurrLineupPos()
    local oPlayer = self:GetPlayer()
    if oPlayer then
        local oPartnerCtrl = oPlayer.m_oPartnerCtrl
        return oPartnerCtrl:GetCurrLineupPos()
    end
end

function CFmtMgr:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function CFmtMgr:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"formation"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function CFmtMgr:GetScore()
    local oPlayer = self:GetPlayer()
    local iScore = 0
    if not oPlayer then
        return iScore
    end
    if not global.oToolMgr:IsSysOpen("FMT_SYS",oPlayer,true) then
        return iScore
    end
    local iGrade = 0
    local oMaxObj
    for iFmt, obj in pairs(self.m_mFmtObj) do
        if iFmt ~=1 and obj:GetGrade()>iGrade then
            iGrade = obj:GetGrade()
            oMaxObj = obj
        end
    end
    if not oMaxObj then  
        return iScore
    end
    local iFmtID = oMaxObj:GetInfo("fmt_id")
    local sScore = oMaxObj:GetBaseInfo()[iFmtID]["score"]
    iScore = formula_string(sScore,{grade = iGrade})
    return iScore
end


