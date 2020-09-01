--import module
--与客户端回调管理
local global = require "global"
local extend = require "base.extend"

function NewCBMgr()
    local oMgr = CCBMgr:New()
    oMgr:Schedule()
    return oMgr
end

CCBMgr = {}
CCBMgr.__index = CCBMgr
inherit(CCBMgr,logic_base_cls())

function CCBMgr:New()
    local o = super(CCBMgr).New(self)
    o.m_iSessionIdx = 0
    o.m_mCallBack = {}
    return o
end

function CCBMgr:Schedule()
    local f1
    f1 = function ()
        self:DelTimeCb("_CheckClean")
        self:AddTimeCb("_CheckClean", 3*60*1000, f1)
        self:_CheckClean()
    end
    f1()
end

function CCBMgr:GetSession()
    self.m_iSessionIdx = self.m_iSessionIdx + 1
    if self.m_iSessionIdx >= 1000000000 then
        self.m_iSessionIdx = 1
    end
    return self.m_iSessionIdx
end

-- FIXME 抽象层，暂时未用，判定下行cmd是否有注册是不必要的，因为封装应该抽象为GS2CToCallback/C2GSCallback，原则上要超时回收
function CCBMgr:SendGS2C(pid, sCmd, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        -- TODO 实现data泛化
        -- oPlayer:Send("GS2CToCallback", {cmd=sCmdl, data=mNet})
    end
end

function CCBMgr:GS2CDialog(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CDialog",mNet)
    end
end

--[[
1.使用任务道具taskitem
]]
function CCBMgr:GS2CLoadUI(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CLoadUI",mNet)
    end
end

--[[
npc回调
]]
function CCBMgr:GS2CNpcSay(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CNpcSay",mNet)
    end
end

function CCBMgr:GS2CPopTaskItem(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CPopTaskItem",mNet)
    end
end

function CCBMgr:GS2CPopTaskSummon(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CPopTaskSummon",mNet)
    end
end

function CCBMgr:GS2COpenShopForTask(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2COpenShopForTask",mNet)
    end
end

function CCBMgr:GS2CHelpTaskGiveItem(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CHelpTaskGiveItem",mNet)
    end
end

function CCBMgr:GS2CShowProgressBar(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CShowProgressBar", mNet)
    end
end

--[[
客户端抽奖表现回调
]]
function CCBMgr:GS2CPlayLottery(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CPlayLottery", mNet)
    end
end

function CCBMgr:GS2CFuYuanLottery(pid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CFuYuanLottery", mNet)
    end
end

function CCBMgr:AutoFindPath(pid, mNet)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:SceneAutoFindPath(pid, mNet.map_id, mNet.pos_x, mNet.pos_y, nil, mNet.autotype, mNet.functype, mNet.sessionidx)
end

function  CCBMgr:GS2CLoadTreasureProgress(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CLoadTreasureProgress",mNet)
    end
end

function  CCBMgr:GS2COpenTaskSayUI(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2COpenTaskSayUI",mNet)
    end
end

function CCBMgr:GS2CStartShowRewardByType( pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CStartShowRewardByType",mNet)
    end
end

function CCBMgr:GS2CConfirmUI(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CConfirmUI",mNet)
    end
end

function CCBMgr:GS2CPlayQte(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CPlayQte",mNet)
    end
end

function CCBMgr:GS2CPlayAnime(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CPlayAnime",mNet)
    end
end

function CCBMgr:GS2CFBComfirm(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CFBComfirm",mNet)
    end
end

function CCBMgr:GS2CJYFBComfirm(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CJYFBComfirm",mNet)
    end
end

function CCBMgr:GS2CExecAfterExchange(pid,mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CExecAfterExchange",mNet)
    end
end

function CCBMgr:GS2CMentorEvalutaion(iPid, mNet)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CMentorEvalutaion", mNet)
    end
end

function CCBMgr:PackConfirmData(pid,mData)
    local mNet = {}
    mNet["sContent"] = mData["sContent"]
    mNet["sConfirm"] = mData["sConfirm"] or "确认"
    mNet["sCancle"] = mData["sCancle"] or "取消"
    mNet["time"] = mData["time"] or 0
    mNet["default"] = mData["default"] or 1
    mNet["extend_close"] = mData["extend_close"] or 1
    mNet["close_btn"] = mData["close_btn"] or 1         --0表示X按钮不发协议
    return mNet
end

function CCBMgr:SetCallBack(pid,sCmd,mData,fResCallBack,fCallback)
    local iSessionIdx
    if fCallback then
        iSessionIdx = self:GetSession()
        mData["sessionidx"] = iSessionIdx
    end
    local func = self[sCmd]
    assert(func,string.format("Callback err:%d %s",pid,sCmd))
    func(self,pid,mData)
    if not fCallback then
        return
    end
    -- _CheckClean定期清理超时的session
    self.m_mCallBack[iSessionIdx] = {pid,fResCallBack,fCallback,get_time()}
    return iSessionIdx
end

function CCBMgr:GetCallBack(iSessionIdx)
    return self.m_mCallBack[iSessionIdx]
end

function CCBMgr:RemoveCallBack(iSessionIdx)
    self.m_mCallBack[iSessionIdx] = nil
end

function CCBMgr:CallBack(oPlayer,iSessionIdx,mData)
    local pid = oPlayer.m_iPid
    local mCallBack = self:GetCallBack(iSessionIdx)
    if not mCallBack then
        return
    end
    local iOwner,fResCallBack,fCallback = table.unpack(mCallBack)
    if iOwner ~= pid then
        return
    end
    -- assert(iOwner==pid,string.format("Callback err %d %d %d",iSessionIdx,pid,iOwner))
    self:RemoveCallBack(iSessionIdx)

    if fResCallBack then
        if not fResCallBack(oPlayer,mData) then
            return
        end
    end
    if not fCallback then
        return
    end
    fCallback(oPlayer,mData)
end

function CCBMgr:_CheckClean()
    local iNowTime = get_time()
    for key,value in pairs(self.m_mCallBack) do
        if iNowTime - value[4]  > 3*60 then
            self.m_mCallBack[key] = nil
        end
    end
end
