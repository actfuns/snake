local global = require "global"
local res = require "base.res"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

local STATE = {
    OPEN = 1,
    CLOSE = 0,
}

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "商城限时打折"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iState = STATE.CLOSE
    o.m_mInfo = {}
    return o
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    local iPid = oPlayer:GetPid()
    if self:IsOpen() and not self.m_mInfo[iPid] then
        self:SendDiscountMail(oPlayer)
    end
end

function CHuodong:Load(mData)
    mData = mData or {}
    self:Dirty()
    self.m_iState = mData.state or STATE.CLOSE
    self.m_mInfo = table_to_int_key(mData.info or {})
end

function CHuodong:AfterLoad()
    self:CheckState()
end

function CHuodong:Save()
    local mData = {
        state = self.m_iState,
        info = table_to_db_key(self.m_mInfo)
    }
    return mData
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:NewHour(mNow)
    self:CheckState(mNow)
end

function CHuodong:CheckState(mNow)
    local iCurTime = mNow and mNow.time or get_time()
    local mConfig = self:GetConfig()
    local iStartTime = get_str2timestamp(mConfig.start_time)
    local iEndTime = get_str2timestamp(mConfig.end_time)
    if self.m_iState == STATE.OPEN then
        local iSub = iEndTime - iCurTime
        if iSub <= 0 then
            self:Close()
        elseif iSub < 3600 then
            self:AddCloseCb()
        end
    else
        if iCurTime > iEndTime then return end
        local iSub = iStartTime - iCurTime
        if iSub <= 0 then
            self:Open()
        elseif iSub < 3600 then
            self:AddOpenCb()
        end
    end 
end

function CHuodong:AddOpenCb()
    local sCbName = "LimitTimeDiscountStart"
    local mConfig = self:GetConfig()
    local iStartTime = get_str2timestamp(mConfig.start_time)
    local iTime = (iStartTime - get_time()) * 1000
    self:DelTimeCb(sCbName)
    self:AddTimeCb(sCbName, iTime, function()
        if not self:IsOpen() then 
            self:Open()
        end
    end)
end

function CHuodong:AddCloseCb()
    local sCbName = "LimitTimeDiscountEnd"
    local mConfig = self:GetConfig()
    local iEndTime = get_str2timestamp(mConfig.end_time)
    local iTime = (iEndTime - get_time()) * 1000
    self:DelTimeCb(sCbName)
    self:AddTimeCb(sCbName, iTime, function()
        if self:IsOpen() then 
            self:Close()
        end
    end)
end

function CHuodong:Open()
    self:Dirty()
    self.m_iState = STATE.OPEN
    self.m_mInfo = {}
    self:LogState()
    local lAllOnlinePid = table_key_list(global.oWorldMgr:GetOnlinePlayerList())
    global.oToolMgr:ExecuteList(lAllOnlinePid,100,1000,0,"LimitTimeDiscount",function(pid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if not oPlayer then return end
        self:SendDiscountMail(oPlayer)
    end)
end

function CHuodong:Close()
    self:Dirty()
    self.m_iState = STATE.CLOSE
    self:LogState()
end

function CHuodong:LogState()
    local mLogData = {
        state = self.m_iState,
    }
    record.log_db("huodong", "limittimediscount_state", mLogData)
end

function CHuodong:SendDiscountMail(oPlayer)
    self:Dirty()
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iMailId = mConfig.mail_id
    local iItemId = mConfig.item_id
    assert(iMailId and iItemId, "CHuodong %s config error ", self.m_sName)
    local oNewItem = global.oItemLoader:Create(iItemId)
    self:SendMail(iPid, iMailId, { items = {oNewItem} })
    self.m_mInfo[iPid] = true
end

function CHuodong:CheckUseItem(oPlayer, oItem, iCostAmount)
    local iCurTime = get_time()
    local mConfig = self:GetConfig()
    local iStartTime = get_str2timestamp(mConfig.start_time)
    local iEndTime = get_str2timestamp(mConfig.end_time)
    local iCdHour = mConfig.cd_time

    local bUse = true
    local sReason = "limittimediscount itemuse"
    local sMsg
    if iCurTime < iStartTime then
        sMsg = global.oToolMgr:GetTextData(1053, {"itemtext"})
        bUse = false
    elseif iCurTime >= iStartTime and iCurTime <= iEndTime then
        iCostAmount = iCostAmount or 1
        oPlayer:RemoveOneItemAmount(oItem, iCostAmount, sReason)
        oPlayer.m_oStoreCtrl:AddDiscountTime(iCostAmount*iCdHour)
    elseif iCurTime > iEndTime then
        sMsg = global.oToolMgr:GetTextData(1055, {"itemtext"})
        iCostAmount = oPlayer:GetItemAmount(oItem:SID())
        oPlayer:RemoveItemAmount(oItem:SID(), iCostAmount or 1, sReason)
    end
    
    if sMsg then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
    end

    return bUse
end

function CHuodong:IsOpen()
    return self.m_iState == STATE.OPEN
end

function CHuodong:GetConfig()
    return table_get_depth(res, {"daobiao", "limittimediscount", 1})
end

function CHuodong:TestOp(iFlag, mArgs)
    local iPid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 开启活动 huodongop limittimediscount 101
        102 - 关闭活动 huodongop limittimediscount 102
        103 - 修改表时间后刷新生效 huodongop limittimediscount 103
        104 - 设置玩家时间n秒后到期 huodongop limittimediscount 104 {sec=10}
        105 - 清空玩家时间 huodongop limittimediscount 105
        ]])
    elseif iFlag == 101 then
        if not self:IsOpen() then
            local mConfig = self:GetConfig()
            local iStartTime = get_str2timestamp(mConfig.start_time)
            local iEndTime = get_str2timestamp(mConfig.end_time)
            local iNowTime = get_time()
            if iNowTime >= iStartTime and iNowTime <= iEndTime then
                self:Open()
                global.oNotifyMgr:Notify(iPid, "开启成功")
            else
                global.oNotifyMgr:Notify(iPid, "当前时间不在配表时间段内")
            end
        else
            global.oNotifyMgr:Notify(iPid, "活动已开启")
        end
    elseif iFlag == 102 then
        if self:IsOpen() then
            self:Close()
            global.oNotifyMgr:Notify(iPid, "关闭成功")
        else
            global.oNotifyMgr:Notify(iPid, "活动已关闭")
        end
    elseif iFlag == 103 then
        self.m_iState = STATE.CLOSE
        self.m_mInfo = {}
        self:CheckState()
        global.oNotifyMgr:Notify(iPid, "刷新成功")
    elseif iFlag == 104 then
        local iSec = mArgs.sec or 10
        local iEndTime = get_time() + iSec
        oPlayer.m_oStoreCtrl.m_iDiscountEnd = iEndTime
        oPlayer.m_oStoreCtrl:AddDiscountCb()
        oPlayer.m_oStoreCtrl:GS2CDiscountTime()
        oPlayer.m_oStoreCtrl:Dirty()
        global.oNotifyMgr:Notify(iPid, iSec .. "秒后 玩家时间到期")
    elseif iFlag == 105 then
        oPlayer.m_oStoreCtrl.m_iDiscountEnd = 0
        oPlayer.m_oStoreCtrl:AddDiscountCb()
        oPlayer.m_oStoreCtrl:GS2CDiscountTime()
        oPlayer.m_oStoreCtrl:Dirty()
        global.oNotifyMgr:Notify(iPid, "清空玩家时间")
    end
end
