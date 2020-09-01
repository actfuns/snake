local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

OPERATION_GET = 1
OPERATION_OPEN = 2

STATE_UNGET = 1    -- 未领取
STATE_REWARD = 2  -- 已经领取箱子
STATE_REWARDED = 3 --已经获得箱子内道具

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "神秘宝箱"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    local iOpenGrade = global.oToolMgr:GetSysOpenPlayerGrade("MYSTICALBOX")
    if iFromGrade < iOpenGrade and iGrade >= iOpenGrade then
        local mData = { operator = OPERATION_GET}
        self:GS2CMysticalboxGetState(oPlayer, { state = STATE_UNGET})
        self:DelUpgradeEvent(oPlayer)
    end
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("MYSTICALBOX", nil ,true) then return end
    local iOpenGrade = oToolMgr:GetSysOpenPlayerGrade("MYSTICALBOX")
    if oPlayer:GetGrade() < iOpenGrade then
        self:AddUpgradeEvent(oPlayer)
        return
    end
    local mPlayerSaveInfo = oPlayer:Query(self:GetPlayerSaveKey(), nil)
    if not mPlayerSaveInfo then
        self:GS2CMysticalboxGetState(oPlayer, { state = STATE_UNGET})
        return
    end

    if mPlayerSaveInfo.reward == STATE_REWARD  then
        self:GS2CMysticalboxGetState(oPlayer, {state = mPlayerSaveInfo.reward, open_time = mPlayerSaveInfo.open_time })
        return
    end
end

function CHuodong:C2GSMysticalboxOperateBox(oPlayer, iOperator)
    if iOperator == 1 then
        self:GetBox(oPlayer)
    elseif iOperator == 2 then
        self:OpenBox(oPlayer)
    end
end


function CHuodong:GS2CMysticalboxGetState(oPlayer, mData)
    local mNet = {
        state = mData.state,
        open_time = mData.open_time
    }
    oPlayer:Send("GS2CMysticalboxGetState", mNet)
end

function CHuodong:GetPlayerSaveKey()
    return "mysticalbox"
end

function CHuodong:GetBox(oPlayer)
    if not global.oToolMgr:IsSysOpen("MYSTICALBOX", oPlayer, true) then return end
    local mNow = get_timetbl()
    local mPlayerSaveInfo = oPlayer:Query(self:GetPlayerSaveKey(), nil)
    if not mPlayerSaveInfo then
        local mConfig = self:GetConfig()
        mPlayerSaveInfo = {}
        mPlayerSaveInfo.reward = STATE_REWARD
        mPlayerSaveInfo.open_time = mNow.time + mConfig.lock_time
        local mLogData = {}
        mLogData.get_time = mNow.time
        record.log_db("huodong","mysticalbox_getbox", { pid = oPlayer:GetPid(), info = mLogData})
        oPlayer:Set(self:GetPlayerSaveKey(), mPlayerSaveInfo)
    end
    local mNet = { state = mPlayerSaveInfo.reward, open_time = mPlayerSaveInfo.open_time}
    self:GS2CMysticalboxGetState(oPlayer, mNet)
end

function CHuodong:OpenBox(oPlayer)
    if not global.oToolMgr:IsSysOpen("MYSTICALBOX", oPlayer, true) then return end
    
    local mPlayerSaveInfo = oPlayer:Query(self:GetPlayerSaveKey(), nil)
    if not mPlayerSaveInfo then return end

    local mNow = get_timetbl()
    local pid = oPlayer:GetPid()
    if mPlayerSaveInfo.open_time > mNow.time then
        -- 领取时间未到达
        global.oNotifyMgr:Notify(pid, self:GetTextData(1001))
        return
    end

    if mPlayerSaveInfo.reward == STATE_REWARDED then
        -- 已经领取了神秘宝箱
        global.oNotifyMgr:Notify(pid, self:GetTextData(1002))
        return
    end

    local lItemIdx = self:GetRewardItemIdx()
    local mItemList = {}
    for _, iItemIdx in pairs(lItemIdx) do
        local mItemUnit = self:InitRewardItem(oPlayer, iItemIdx, {})
        list_combine(mItemList, mItemUnit["items"])
    end
    -- 先判断背包格子
    if not oPlayer:ValidGiveitemlist(mItemList, {cancel_tip = false}) then return end

    local mLogData = {}
    mLogData.reward = extend.Table.serialize(lItemIdx)
    record.log_db("huodong","mysticalbox_rewarded",{ pid = oPlayer:GetPid(), info = mLogData})
    mPlayerSaveInfo.reward = STATE_REWARDED
    oPlayer:Set(self:GetPlayerSaveKey(), mPlayerSaveInfo)
    oPlayer:GiveItemobj(mItemList, self.m_sName, {})
    self:GS2CMysticalboxGetState(oPlayer, { state = mPlayerSaveInfo.reward})
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"]["mysticalbox"]["config"]
end

function CHuodong:GetRewardID()
    return res["daobiao"]["huodong"]["mysticalbox"]["reward"][1].reward_id
end

function CHuodong:GetRewardItemIdx()
    local iRewardId = self:GetRewardID()
    return res["daobiao"]["reward"]["mysticalbox"]["reward"][iRewardId]["item"]
end

function CHuodong:TestOp(iFlag, mArgs)
    local netcmd = import(service_path("netcmd.huodong"))
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
100 - huodongop mysticalbox
101 - 领取箱子到身上
102 - 查看领取状态
103 - 打开箱子获取物品
104 - 清空玩家的领取记录
105 - 设置为可领取物品（将领取箱子的时间向前设置）
106 - 发送可领取箱子消息（19 --> 20 级）
            ]])
    elseif iFlag == 101 then
        netcmd.C2GSMysticalboxOperateBox(oMaster, {operator = OPERATION_GET})
    elseif iFlag == 102 then
        local mPlayerSaveInfo = oMaster:Query(self:GetPlayerSaveKey(),nil)
        if not mPlayerSaveInfo then
            global.oNotifyMgr:Notify(pid, "还未领取")
        else
            local sTime = os.date("%x %X", mPlayerSaveInfo.open_time)
            local sMsg = "状态" .. mPlayerSaveInfo.reward .. "允许打开时间" .. sTime
            global.oChatMgr:HandleMsgChat(oMaster, sMsg)
        end
    elseif iFlag == 103 then
        netcmd.C2GSMysticalboxOperateBox(oMaster, {operator = OPERATION_OPEN})
    elseif iFlag == 104 then
        oMaster:Set(self:GetPlayerSaveKey(),nil)
    elseif iFlag == 105 then
        local mPlayerSaveInfo = oMaster:Query(self:GetPlayerSaveKey(),nil)
        if mPlayerSaveInfo then
            local mConfig = self:GetConfig()
            mPlayerSaveInfo.open_time = mPlayerSaveInfo.open_time - mConfig.lock_time
            oMaster:Set(self:GetPlayerSaveKey(), mPlayerSaveInfo)
            self:GS2CMysticalboxGetState(oMaster, {state = mPlayerSaveInfo.reward, open_time = mPlayerSaveInfo.open_time})
        end
    elseif iFlag == 106 then
        self:GS2CMysticalboxGetState(oMaster, { state = STATE_UNGET}) 
    end
end

