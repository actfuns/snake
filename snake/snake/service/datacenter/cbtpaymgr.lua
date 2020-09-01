local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewCbtPayMgr(...)
    local o = CCbtPayMgr:New(...)
    return o
end

CCbtPayMgr = {}
CCbtPayMgr.__index = CCbtPayMgr
inherit(CCbtPayMgr, datactrl.CDataCtrl)

function CCbtPayMgr:New()
    local o = super(CCbtPayMgr).New(self)
    o:Init()
    return o
end

function CCbtPayMgr:Init()
    self.m_mCbtPay = {}
end

function CCbtPayMgr:LoadDb()
    local mInfo = {
        module = "cbtpaydb",
        cmd = "LoadCbtPay",
    }
    gamedb.LoadDb("cbtpay", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        self:Load(mData.data)
    end)
end

function CCbtPayMgr:Load(mData)
    self.m_mCbtPay = {}
    for _, m in pairs(mData) do
        if not m.pid then
            local sKey = self:GenKey(m.account, m.channel)
            self.m_mCbtPay[sKey] = m
        end
    end
end

function CCbtPayMgr:SaveDb(sKey)
    local mCbtPay = self.m_mCbtPay[sKey]
    if not mCbtPay then return end

    local mInfo = {
        module = "cbtpaydb",
        cmd = "SaveCbtPay",
        cond = {account = mCbtPay.account, channel = mCbtPay.channel},
        data = mCbtPay,
    }
    gamedb.SaveDb("cbtpay", "common", "DbOperate", mInfo)
end

function CCbtPayMgr:GenKey(sAccount, iChannel)
    return string.format("%d_%s", iChannel, sAccount) 
end

function CCbtPayMgr:GetCbtPayInfo(sAccount, iChannel)
    local sKey = self:GenKey(sAccount, iChannel)
    local mCbtPay = self.m_mCbtPay[sKey]
    return mCbtPay
end

function CCbtPayMgr:TryGetReturnReward(sAccount, iChannel, iPid, sName, iIdx)
    local sKey = self:GenKey(sAccount, iChannel)
    local mCbtPay = self.m_mCbtPay[sKey]
    if not mCbtPay then
        return 1, mCbtPay
    end

    local mReward = mCbtPay.reward or {}
    if not mReward[db_key(iIdx)] then
        mReward[db_key(iIdx)] = {pid=iPid, name=sName}
        mCbtPay.reward = mReward
        self.m_mCbtPay[sKey] = mCbtPay
        self:SaveDb(sKey)
        record.log_db("huodong", "return_goldcoin", {
            pid = iPid,
            name = sName,
            type = "reward"..iIdx,
        })
        return 0, mCbtPay
    end

    return 2, mCbtPay
end

function CCbtPayMgr:TryGetFreeGift(sAccount, iChannel, iPid, sName)
    local sKey = self:GenKey(sAccount, iChannel)
    local mCbtPay = self.m_mCbtPay[sKey]
    if not mCbtPay then
        return 1, mCbtPay
    end

    if not mCbtPay.free_gift then
        mCbtPay.free_gift = {pid=iPid, name=sName}
        self:SaveDb(sKey)
        record.log_db("huodong", "return_goldcoin", {
            pid = iPid,
            name = sName,
            type = "free_gift",
        })
        return 0, mCbtPay
    end

    return 2, mCbtPay
end

function CCbtPayMgr:GmSetCbtData(sAccount, iChannel, iPayCount)
    local sKey = self:GenKey(sAccount, iChannel)
    local mCbtPay = {
        channel = iChannel,
        account = sAccount,
        paycount = iPayCount,
    }
    self.m_mCbtPay[sKey] = mCbtPay
    self:SaveDb(sKey)
    return mCbtPay
end
