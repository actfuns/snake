local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local serverinfo = import(lualib_path("public.serverinfo"))

local STATUS_UNREACH = 0
local STATUS_REWARD = 1
local STATUS_REWARDED = 2


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "集字活动"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_mCollect = {}
end

function CHuodong:Save()
    local mData = {}

    mData.collect = {}
    for sKey, obj in pairs(self.m_mCollect) do
        mData.collect[sKey] = obj:Save()
    end
    return mData
end

function CHuodong:Load(mData)
    if not mData then return end
    
    for sKey, m in pairs(mData.collect or {}) do
        local o = self.m_mCollect[sKey]
        if o then
            o:Load(m)    
        end
    end
end

function CHuodong:Release()
    for _, o in pairs(self.m_mCollect) do
        baseobj_safe_release(o)
    end
    self.m_mCollect = {}
    super(CHuodong).Release(self)
end

function CHuodong:IsDirty()
    local bDirty = super(CHuodong).IsDirty(self)
    if bDirty then return true end

    for _, o in pairs(self.m_mCollect) do
        if o:IsDirty() then return true end
    end
    return false
end

function CHuodong:UnDirty()
    super(CHuodong).UnDirty(self)
    for _, o in pairs(self.m_mCollect) do
        if o:IsDirty() then
            o:UnDirty()
        end
    end
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:RefreshCollectInfo(oPlayer)
end

function CHuodong:NewHour(mNow)
    self:CheckCollectEnd(mNow)
    local iHour = mNow.date.hour
    if iHour == 5 and table_count(self.m_mCollect) > 0 then
        self:TryStopRewardMonitor()
    end
end

function CHuodong:ParseTime(sTime)
    local year,month,day,hour,min= sTime:match('^(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)')
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = 0,
        sec = 0,
    })
end

function CHuodong:GetCollectObj(sKey)
    return self.m_mCollect[sKey]
end

function CHuodong:RemoveCollect(sKey)
    local oCollect = self.m_mCollect[sKey]
    if not oCollect then return end

    baseobj_delay_release(oCollect)
    self.m_mCollect[sKey] = nil
    self:Dirty()
end

function CHuodong:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    return true
end

function CHuodong:CheckCollectEnd(mNow)
    local lExpire = {}
    for sKey, oCollect in pairs(self.m_mCollect) do
        if oCollect:IsExpire(mNow) then
            table.insert(lExpire, sKey)
        end
    end

    for _, sKey in pairs(lExpire) do
        self:CollectEnd(sKey)
    end

    if table_count(self.m_mCollect) <= 0 then
        self:TryStopRewardMonitor()
    end
end

function CHuodong:CollectEnd(sKey)
    self:RemoveCollect(sKey)
    self:UpdateCollectStatus(sKey, 0)
    record.info("huodong collect end %s, %d", sKey, table_count(self.m_mCollect))
    global.oHotTopicMgr:UnRegister(self.m_sName)
end

function CHuodong:CollectStart(sKey, iStartTime, iEndTime)
    if not global.oToolMgr:IsSysOpen("WELFARE_COLLECT", oPlayer, true) then
        return
    end

    local oCollect = CCollect:New(sKey)
    oCollect:Create(iStartTime, iEndTime, iStartTime, iEndTime)
    self.m_mCollect[sKey] = oCollect
    self:Dirty()
    self:UpdateCollectStatus(sKey, 1)
    record.info("huodong collect start %s, %d", sKey, table_count(self.m_mCollect))

    if table_count(self.m_mCollect) > 0 then
        self:TryStartRewardMonitor()
    end
    global.oHotTopicMgr:Register(self.m_sName)
end

function CHuodong:RegisterHD(mInfo, bClose)
    if self.m_sName ~= mInfo["hd_type"] then 
        return false, "name error"
    end
    local sKey = mInfo["hd_key"]
    if not self:GetCollectConfigInfo()[sKey] then
        return false, "not hd_key"
    end

    local iStartTime = mInfo["start_time"]
    local iEndTime = mInfo["end_time"]
    if bClose then
        local oCollect = self:GetCollectObj(sKey)
        if oCollect then
            self:CollectEnd(sKey)
        end
    else
        local oCollect = self:GetCollectObj(sKey)
        if not oCollect then
            self:CollectStart(sKey, iStartTime, iEndTime)
        else
            oCollect.m_iCoStartTime = iStartTime
            oCollect.m_iCoEndTime = iEndTime
            oCollect.m_iReStartTime = iStartTime
            oCollect.m_iReEndTime = iEndTime
        end
    end
    return true
end

function CHuodong:TriggerCollectReward(iPid, sType, iKey)
    if self.m_sName == sType then return end

    if table_count(self.m_mCollect) <= 0 then return end

    for sKey, oCollect in pairs(self.m_mCollect) do
        local mConfig = self:GetCollectItem(sKey, sType)
        if oCollect:IsCollect() and mConfig and table_in_list(mConfig["condition_ids"], iKey) then
            self:Reward(iPid, mConfig["collect_reward"])            
        end
    end
end

function CHuodong:TryRewardCollectGift(oPlayer, sGiftKey)
    if not global.oToolMgr:IsSysOpen("WELFARE_COLLECT", oPlayer) then
        return
    end

    local mConfig = self:GetCollectGiftInfo()[sGiftKey]
    if not mConfig then return end

    local sKey = mConfig["collect_key"]
    local oCollect = self:GetCollectObj(sKey)
    if not oCollect or oCollect:IsExpire() then
        self:NotifyMessage(oPlayer, 1001)
        return
    end

    if not oCollect:IsRedeem() then
        self:NotifyMessage(oPlayer, 1001)
        return
    end

    local iHasRedeem = oCollect:GetRedeemCnt(oPlayer:GetPid(), sGiftKey)
    if mConfig["redeem_num"] > 0 and iHasRedeem >= mConfig["redeem_num"] then
        self:NotifyMessage(oPlayer, 1003)
        return
    end
    
    local mCostItem = mConfig["cost_item"]
    for _, mItem in pairs(mCostItem) do
        if oPlayer:GetItemAmount(mItem["sid"]) < mItem["num"] then
            self:NotifyMessage(oPlayer, 1002)
            return
        end
    end
    local mCostItem = mConfig["cost_item"]
    for _, mItem in pairs(mCostItem) do
        oPlayer:RemoveItemAmount(mItem["sid"], mItem["num"], "集字兑换")
    end

    local iReward = mConfig['reward']
    oCollect:AddRedeemCnt(oPlayer:GetPid(), sGiftKey)
    self:Reward(oPlayer:GetPid(), iReward)
    self:RefreshCollectInfo(oPlayer)
    local mInfo = {
        action = "reward_collect_gfit",
        key = sGiftKey,
    }
    record.log_db("huodong", "welfare", {pid=oPlayer:GetPid(), info=mInfo})
end

function CHuodong:UpdateCollectStatus(sKey, iStatus)
    local mNet = {}    
    mNet["collect_key"] = sKey 
    mNet["status"] = iStatus
    local oCollect = self:GetCollectObj(sKey)
    if oCollect then
        mNet["collect"] = oCollect:PackCollect()    
    end
    local mData = {
        message = "GS2CUpdateCollectStatus",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = mNet,
    }
    interactive.Send(".broadcast", "channel", "SendChannel", mData)
end

function CHuodong:RefreshCollectInfo(oPlayer)
    local mNet = {}
    mNet.collect_gift = {}
    for _, oCollect in pairs(self.m_mCollect) do
        table.insert(mNet.collect_gift, oCollect:PackCollect(oPlayer))
    end
    oPlayer:Send("GS2CCollectGiftInfo", mNet)
end

function CHuodong:NotifyMessage(oPlayer, iText, mRep)
    local sMsg = self:GetTextData(iText)
    if mRep then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oPlayer:NotifyMessage(sMsg)
end

function CHuodong:MergeFrom(mFromData)
    -- 策划被合服的数据不需要处理(删除)
    return true
end

function CHuodong:GetCollectConfigInfo()
    return res["daobiao"]["huodong"][self.m_sName]["collect_config"]
end

function CHuodong:GetCollectGiftInfo()
    return res["daobiao"]["huodong"][self.m_sName]["collect_gift"]
end

function CHuodong:GetCollectItem(sKey, sType)
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["collect_item"]
    for _, mData in pairs(mConfig) do
        if mData["hd_key"] == sType and mData["collect_key"] == sKey then
            return mData
        end
    end
    return nil
end

function CHuodong:IsHuodongOpen()
    if  next(self.m_mCollect) then
        return true
    else
        return false
    end
end

-------------------TestOp--------------------------
function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mCommand = {
        "101.check开启\nhuodongop collect 101",
        "102.check结束\nhuodongop collect 102",
        "103.结束活动\nhuodongop collect 103",
        "104.开始活动2小时\nhuodongop collect 104",
    }
    if iFlag == 100 then
        for idx=#mCommand, 1, -1 do
            global.oChatMgr:HandleMsgChat(oMaster, mCommand[idx])
        end
    elseif iFlag == 101 then
        -- self:CheckCollectStart()
    elseif iFlag == 102 then
        self:CheckCollectEnd()
    elseif iFlag == 103 then
        local sKey = "collect_key_1"
        self:CollectEnd(sKey)    
    elseif iFlag == 104 then
        local sKey = "collect_key_1"
        local mConfig = self:GetCollectConfigInfo()[sKey]
        if not mConfig then
            oMaster:NotifyMessage("没有找到配置")
            return
        end
        local iNow = get_time()
        local iCoStartTime = iNow
        local iCoEndTime = iNow + 3600 * 2
        local iReStartTime = iNow
        local iReEndTime = iNow + 3600 * 2
        local oCollect = CCollect:New(sKey)
        oCollect:Create(iCoStartTime, iCoEndTime, iReStartTime, iReEndTime)
        self.m_mCollect[sKey] = oCollect
        self:Dirty()
        self:UpdateCollectStatus(sKey, 1)
    end
end

-------------------集字兑换--------------------------
CCollect = {}
CCollect.__index = CCollect
inherit(CCollect, datactrl.CDataCtrl)

function CCollect:New(sKey)
    local o = super(CCollect).New(self, {key=sKey})
    o:Init()
    return o
end

function CCollect:Init()
    self.m_iCoStartTime = 0
    self.m_iCoEndTime = 0
    self.m_iReStartTime = 0
    self.m_iReEndTime = 0
    self.m_mPlayer = {}
end

function CCollect:Release()
    self.m_mPlayer = {}
    super(CCollect).Release(self)
end

function CCollect:Create(iCoStartTime, iCoEndTime, iReStartTime, iReEndTime)
    self.m_iCoStartTime = iCoStartTime
    self.m_iCoEndTime = iCoEndTime
    self.m_iReStartTime = iReStartTime
    self.m_iReEndTime = iReEndTime
end

function CCollect:Load(mData)
    if not mData then return end

    -- self.m_iCoStartTime = mData["co_start_time"]
    -- self.m_iCoEndTime = mData["co_end_time"]
    -- self.m_iReStartTime = mData["re_start_time"]
    -- self.m_iReEndTime = mData["re_end_time"]
    for sPid, m in pairs(mData["redeem"] or {}) do
        self.m_mPlayer[tonumber(sPid)] = m
    end
end

function CCollect:Save()
    local mData = {}
    -- mData["co_start_time"] = self.m_iCoStartTime
    -- mData["co_end_time"] = self.m_iCoEndTime
    -- mData["re_start_time"] = self.m_iReStartTime
    -- mData["re_end_time"] = self.m_iReEndTime

    local mRedeem = {}
    for iPid, m in pairs(self.m_mPlayer) do
        mRedeem[db_key(iPid)] = m
    end
    mData["redeem"] = mRedeem
    return mData
end

function CCollect:IsCollect()
    if self.m_iCoStartTime >= self.m_iCoEndTime then return false end

    local iNow = get_time()
    if iNow < self.m_iCoStartTime then return false end

    if iNow > self.m_iCoEndTime then return false end

    return true
end

function CCollect:IsRedeem()
    if self.m_iReStartTime >= self.m_iReEndTime then return false end

    local iNow = get_time()
    if iNow < self.m_iReStartTime then return false end

    if iNow > self.m_iReEndTime then return false end

    return true
end

function CCollect:IsExpire(mNow)
    local iNow = mNow and mNow.time or get_time()
    if iNow >= self.m_iReEndTime and iNow >= self.m_iCoEndTime then return true end

    return false
end

function CCollect:GetRedeemCnt(iPid, sGiftKey)
    local mRedeem = self.m_mPlayer[iPid] or {}
    return mRedeem[sGiftKey] or 0
end

function CCollect:AddRedeemCnt(iPid, sGiftKey)
    local mRedeem = self.m_mPlayer[iPid]
    if not mRedeem then
        mRedeem = {}
        self.m_mPlayer[iPid] = mRedeem
    end
    mRedeem[sGiftKey] = (mRedeem[sGiftKey] or 0) + 1
    self:Dirty()
end

function CCollect:GetReStartTime()
    return self.m_iReStartTime
end

function CCollect:GetReEndTime()
    return self.m_iReEndTime
end

function CCollect:PackCollect(oPlayer)
    local mNet = {}
    mNet.collect_key = self:GetInfo("key")
    mNet.start_time = self.m_iReStartTime
    mNet.end_time = self.m_iReEndTime
    mNet.gift_list = {}
    
    if oPlayer then
        local mRedeem = self.m_mPlayer[oPlayer:GetPid()] or {}
        for sGiftKey, iCnt in pairs(mRedeem) do
            table.insert(mNet.gift_list, {key = sGiftKey, val = iCnt})
        end
    end
    return mNet
end

