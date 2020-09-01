local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "祝福瓶"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mBottle = {}
    o.m_mPid2Bottle = {}
    o.m_iDispatchId = 0
    o.m_iStartTime = 0
    o:Init()
    return o
end

function CHuodong:Init(mNow)
    self:DelTimeCb("SysSendBottle")
    self:InitGameStartTime(mNow)
    self:CheckAddTimer(mNow)
end

function CHuodong:NewDay(mNow)
    self:Init(mNow)
end

function CHuodong:NewHour(mNow)
    self:CheckAddTimer(mNow)
end

function CHuodong:InitGameStartTime(mNow)
    local mConfig = GetConfig()
    local lStartTime = split_string(mConfig.start_time, "|", function(sTime)
        return self:AnalyseTime(sTime)
    end)
    local iTime = mNow and mNow.time or get_time()
    for _, iStartTime in ipairs(lStartTime) do
        if iTime < iStartTime then
            self.m_iStartTime = iStartTime
            return
        end
    end
    self.m_iStartTime = 0
end

function CHuodong:CheckAddTimer(mNow)
    if self.m_iStartTime == 0 then return end

    local iTime = mNow and mNow.time or get_time()
    local iDelta = self.m_iStartTime - iTime
    if iDelta > 0 and iDelta <= 3600 then
        self:DelTimeCb("SysSendBottle")
        self:AddTimeCb("SysSendBottle", iDelta*1000, function()
            self:SysSendBottle()
        end)
    end
end

function CHuodong:AnalyseTime(sTime)
    local mCurrDate = os.date("*t", get_time())
    local year,month,day,hour,min= sTime:match('^(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)')
    return os.time({
        year = year == "0" and mCurrDate.year or tonumber(year),
        month = month == "0" and mCurrDate.month or tonumber(month),
        day = (day == "0") and mCurrDate.day or tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0,
    })
end

function CHuodong:SysSendBottle()
    local mConfig = GetConfig()
    local iBottleMax = mConfig.bottle_max
    local iCurrCnt = table_count(self.m_mBottle)
    local iSize = iBottleMax - iCurrCnt
    if iSize <= 0 then return end

    local lPlayer = self:ChooseRecv({}, iSize)
    for _, iPid in pairs(lPlayer or {}) do
        local oBottle = self:GenBottle()
        oBottle:Send(iPid)
    end
end

function CHuodong:CanGetBottle(oPlayer)
    local mConfig = GetConfig()
    if not global.oToolMgr:IsSysOpen("BOTTLE", oPlayer, true) then
        return false
    end
    if oPlayer.m_oTodayMorning:Query("bottle_recv", 0) >= mConfig.recv_max then
        return false
    end
    if oPlayer.m_oThisTemp:Query("gap_time") then
        return false
    end
    return true
end

function CHuodong:FilterPlayer(mFilter)
    local lResult = {}
    local mPlayerList = global.oWorldMgr:GetOnlinePlayerList()
    local lPidList = table_key_list(mPlayerList)
    local iOnlineCnt = #lPidList

    if iOnlineCnt <= 0 then return lResult end

    local iStart = math.random(math.max(1, iOnlineCnt-100))
    for idx = iStart, math.min(iStart+100, iOnlineCnt) do
        local iPid = lPidList[idx]
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            goto continue
        end
        if mFilter[iPid] then
            goto continue
        end
        if self.m_mPid2Bottle[iPid] then
            goto continue
        end
        if not self:CanGetBottle(oPlayer) then
            goto continue
        end
        table.insert(lResult, iPid)
        ::continue::
    end
    return lResult
end

function CHuodong:ChooseRecv(mFilter, iSize)
    local lOnline = self:FilterPlayer(mFilter)
    if not next(lOnline) then return {} end

    return extend.Random.random_size(lOnline, iSize)
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local iPid = oPlayer:GetPid()
    local iBottle = self:GetBottleIdByPid(iPid)
    if iBottle then
        self:ReceiveBottle(iPid, iBottle)
    end
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:C2GSBottleDetail(oPlayer, iBottle)
    local oBottle = self:GetBottleById(iBottle)
    local iPid = oPlayer:GetPid()
    if not oBottle or oBottle.m_iRecv ~= iPid then
        self:Notify(iPid, 1004)
        return
    end

    local mNet = oBottle:PackInfo()
    oPlayer:Send("GS2CBottleDetail", mNet)
end

function CHuodong:C2GSBottleSend(oPlayer, iBottle, sContent)
    local oBottle = self:GetBottleById(iBottle)
    local iPid = oPlayer:GetPid()
    if not oBottle or oBottle.m_iRecv ~= iPid then
        self:Notify(iPid, 1004)
        return
    end
    if sContent and #trim(sContent) <= 0 then
        self:Notify(iPid, 1003)
        return
    end

    local _, iRecv = next(self:ChooseRecv({[iPid]=1}, 1))
    iRecv = self.m_iSetTarget or iRecv
    if not iRecv then
        self:TryRemoveBottle(iBottle)
    else
        local mInfo = self:PackSendInfo(oPlayer, sContent)
        oBottle:Init(mInfo)
        oBottle:Send(iRecv)
    end

    local mConfig = GetConfig()
    self:Reward(iPid, mConfig.reward_idx)
    self:Notify(iPid, 1002)
end

function CHuodong:PackSendInfo(oPlayer, sContent)
    local mInfo = {}
    mInfo.send = oPlayer:GetPid()
    mInfo.name = oPlayer:GetName()
    mInfo.model_info = oPlayer:GetModelInfo()
    mInfo.content = sContent
    return mInfo
end

function CHuodong:DispatchBottleId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CHuodong:GenBottle()
    local iBottle = self:DispatchBottleId()
    local oBottle = NewBottle(iBottle)
    self.m_mBottle[iBottle] = oBottle
    return oBottle
end

function CHuodong:TryRemoveBottle(iBottle, sReason)
    local oBottle = self.m_mBottle[iBottle]
    if not oBottle then return end

    local iRecv = oBottle.m_iRecv
    self.m_mPid2Bottle[iRecv] = nil
    self.m_mBottle[iBottle] = nil
    local iSend = oBottle.m_iSend
    if iSend and iSend > 0 then
        self.m_mPid2Bottle[iSend] = nil
    end
    baseobj_delay_release(oBottle)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iRecv)
    if oPlayer then
        oPlayer:Send("GS2CBottleRecv", {bottle=nil})
    end
end

function CHuodong:TryAutoSend2Next(iBottle, iIdentify)
    local oBottle = self:GetBottleById(iBottle)
    if not oBottle then return end

    if iIdentify ~= oBottle:GetTime() then return end

    local iOldRecv = oBottle.m_iRecv
    local _, iRecv = next(self:ChooseRecv({[iOldRecv]=1}, 1))
    if not iRecv then
        self:TryRemoveBottle(iBottle)
    else
        self.m_mPid2Bottle[iOldRecv] = nil
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOldRecv)
        if oPlayer then
            oPlayer:Send("GS2CBottleRecv", {bottle=nil})
        end
        oBottle:Send(iRecv)
    end
    self:Notify(iOldRecv, 1004)
end

function CHuodong:GetBottleIdByPid(iPid)
    return self.m_mPid2Bottle[iPid]
end

function CHuodong:GetBottleById(iBottle)
    return self.m_mBottle[iBottle]
end

function CHuodong:ReceiveBottle(iPid, iBottle)
    local oBottle = self:GetBottleById(iBottle)
    if not oBottle then return end
   
    local oWorldMgr = global.oWorldMgr 
    local iSend = oBottle.m_iSend
    if iSend and iSend > 0 then
        self.m_mPid2Bottle[iSend] = nil
        local oSend = oWorldMgr:GetOnlinePlayerByPid(iSend)
        if oSend then
            oSend:Send("GS2CBottleRecv", {bottle=nil})
        end
    end

    self.m_mPid2Bottle[iPid] = iBottle
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local mConfig = GetConfig()
        local iSetTime = get_time() + mConfig.gap_time
        oPlayer.m_oTodayMorning:Add("bottle_recv", 1)
        oPlayer.m_oThisTemp:Reset("gap_time", iSetTime, mConfig.gap_time)
        oPlayer:Send("GS2CBottleRecv", {bottle=iBottle})
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 模拟系统发送瓶子
        102 - 所有瓶子自动传递
        103 - 查看当前瓶子id
        104 - 传递瓶子给指定玩家 {iBottle, iPid}
        105 - 查看所有瓶子id
        106 - 指定目标
        ]])
    elseif iFlag == 101 then
        self:SysSendBottle()
    elseif iFlag == 102 then
        for iBottle, oBottle in pairs(self.m_mBottle) do
            local iTime = oBottle:GetTime()
            self:TryAutoSend2Next(iBottle, iTime)
        end
    elseif iFlag == 103 then
        local iBottle = self.m_mPid2Bottle[iPid]
        if iBottle then
            global.oNotifyMgr:Notify(iPid, "bottle:"..iBottle)
        else
            global.oNotifyMgr:Notify(iPid, "empty bottle")
        end
    elseif iFlag == 104 then
        local iBottle = tonumber(mArgs[1])
        local iRecv = tonumber(mArgs[2])
        local oBottle = self:GetBottleById(iBottle)
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iRecv)
        if oBottle and oTarget then
            local mInfo = self:PackSendInfo(oMaster, "gm op")
            oBottle:Init(mInfo)
            oBottle:Send(iRecv)
        else
            global.oNotifyMgr:Notify(iPid, "指令格式不对，或者目标不在线")
        end
    elseif iFlag == 105 then
        local lBottle = table_key_list(self.m_mBottle) do
            global.oNotifyMgr:Notify(iPid, string.format("所有瓶子：%s", extend.Table.serialize(lBottle)))
        end
    elseif iFlag == 106 then
        self.m_iSetTarget = mArgs[1]
    end
end



function NewBottle(id)
    return CBottle:New(id)
end

CBottle = {}
CBottle.__index = CBottle
inherit(CBottle, logic_base_cls())

function CBottle:New(id)
    local o = super(CBottle).New(self)
    o.m_ID = id
    o.m_iSend = 0
    o.m_iRecv = 0
    o.m_sName = ""
    o.m_mModelInfo = {}
    o.m_sContent = ""
    o.m_iCreateTime = get_time()
    return o
end

function CBottle:Init(mInfo)
    self.m_iSend = mInfo.send
    self.m_sName = mInfo.name
    self.m_mModelInfo = mInfo.model_info
    self.m_sContent = mInfo.content
end

function CBottle:PackInfo()
    local mNet = {}
    mNet.bottle = self.m_ID
    mNet.send_id = self.m_iSend
    mNet.name = self.m_sName
    mNet.content = self.m_sContent
    mNet.send_time = self:GetTime()
    
    local mModel = {}
    mModel.shape = self.m_mModelInfo.shape
    mModel.scale = self.m_mModelInfo.scale
    mModel.color = self.m_mModelInfo.color
    mNet.model_info = mModel

    return mNet
end

function CBottle:GetTime()
    return self.m_iSendTime or self.m_iCreateTime
end

function CBottle:ValidSend()
    local mConfig = GetConfig()
    local iTime = self:GetTime()
    local iCurrTime = get_time()
    if iCurrTime - iTime >= mConfig.bottle_time then
        return false
    end
    return true
end

function CBottle:Send(iPid)
    self.m_iRecv = iPid
    self.m_iSendTime = get_time()
    self:ResetTimer()

    local oHuodong = global.oHuodongMgr:GetHuodong("bottle")
    oHuodong:ReceiveBottle(iPid, self.m_ID)
end

function CBottle:ResetTimer()
    local mConfig = GetConfig()
    local iBottle = self.m_ID
    local iIdentify = self:GetTime()
    self:DelTimeCb("AutoSend")
    self:AddTimeCb("AutoSend", mConfig.bottle_time*1000, function()
        local oHuodong = global.oHuodongMgr:GetHuodong("bottle")
        oHuodong:TryAutoSend2Next(iBottle, iIdentify)
    end)
end


function GetConfig()
    return res["daobiao"]["huodong"]["bottle"]["config"][1]
end

