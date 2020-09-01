--离线档案
local skynet = require "skynet"
local global = require "global"
local router = require "base.router"

local gamedefines = import(lualib_path("public.gamedefines"))
local basectrl = import(service_path("offline.profilectrl"))

CProfileCtrl = {}
CProfileCtrl.__index = CProfileCtrl
inherit(CProfileCtrl, basectrl.CProfileCtrl)

function CProfileCtrl:New(iPid)
    local o = super(CProfileCtrl).New(self, iPid)
    return o
end

function CProfileCtrl:SaveDb()
end

function CProfileCtrl:ConfigSaveFunc()
end

function CProfileCtrl:OnLogin(oPlayer, bReEnter)
end

function CProfileCtrl:SetName(sName)
end

function CProfileCtrl:SetShowId(iNewShowId)
end

function CProfileCtrl:OnLogout(oPlayer)
end

function CProfileCtrl:GetOrg()
end

function CProfileCtrl:GetOrgID()
    return 0
end

function CProfileCtrl:GetOrgName()
    return ""
end

function CProfileCtrl:GetOrgPos()
    return 0
end

function CProfileCtrl:AddUpvote(pid)
end

function CProfileCtrl:FrozenMoney(iType, iVal, sReason, iTime)
end

function CProfileCtrl:UnFrozenMoney(sSession)
end

function CProfileCtrl:AddGoldCoin(iGoldCoin, sReason, mArgs)
    local iPid = self:GetPid()
    local lArgs = {iGoldCoin, sReason, mArgs}
    global.oWorldMgr:LogKSInfo("ks_addgoldcoin", {pid=iPid, goldcoin=iGoldCoin, reason=(sReason or "")})

    self:KS2GSProfileRemoteEvent("AddGoldCoin", lArgs, function (mData)
        local oProfile = global.oWorldMgr:GetProfile(iPid)
        if oProfile then
            oProfile:UpdateProfile(mData)
        end
    end)
end

function CProfileCtrl:AddRplGoldCoin(iRplGold, sReason, mArgs)
    local iPid = self:GetPid()
    local lArgs = {iRplGold, sReason, mArgs}
    global.oWorldMgr:LogKSInfo("ks_addrpgoldcoin", {pid=iPid, rpgoldcoin=iRplGold, reason=(sReason or "")})

    self:KS2GSProfileRemoteEvent("AddRplGoldCoin", lArgs, function (mData)
        local oProfile = global.oWorldMgr:GetProfile(iPid)
        if oProfile then
            oProfile:UpdateProfile(mData)
        end
    end)
end

function CProfileCtrl:CleanGoldCoinOwe()
end

function CProfileCtrl:CleanTrueGoldCoinOwe()
end

function CProfileCtrl:ValidGoldCoin(iGold, mArgs)
    global.oNotifyMgr:Notify(self:GetPid(), "不能使用元宝")
    return false
end

-- 优先绑定
function CProfileCtrl:ResumeGoldCoin(iVal,sReason,mArgs)
    assert(false, string.format("ks cant resume goldcoin %s  err %d", sReason, iVal))
end

function CProfileCtrl:ValidTrueGoldCoin(iGold, mArgs)
    global.oNotifyMgr:Notify(self:GetPid(), "不能使用元宝")
    return false
end

function CProfileCtrl:ResumeTrueGoldCoin(iVal, sReason, mArgs)
    assert(false, string.format("ks cant resume truegoldcoin %s  err %d", sReason, iVal))
end

function CProfileCtrl:ValidRplGoldCoin(iGold, mArgs)
    global.oNotifyMgr:Notify(self:GetPid(), "不能使用元宝")
    return false
end

function CProfileCtrl:ResumeRplGoldCoin(iVal, sReason, mArgs)
    assert(false, string.format("ks cant resume rplgoldcoin %s  err %d", sReason, iVal))
end

function CProfileCtrl:SetTitleInfo(mTitInfo)
end

function CProfileCtrl:ClearTitleInfo()
end

function CProfileCtrl:UpdateProfile(mData)
    self.m_iGoldCoin = mData.goldcoin or self.m_iGoldCoin
    self.m_iRplGoldCoin = mData.rplgoldcoin or self.m_iRplGoldCoin

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        oPlayer:PropChange("goldcoin", "rplgoldcoin")
    end
end

function CProfileCtrl:KS2GSProfileRemoteEvent(sFunc, lArgs, fCallBack)
    local iPid = self:GetPid()
    local sServerKey = global.oWorldMgr:GetServerKey(iPid)
    if sServerKey then
        router.Request(sServerKey, ".world", "kuafu_gs", "KS2GSProfileRemoteEvent", {
            pid = iPid,
            func = sFunc,
            args = lArgs,
        }, function (mRec, mData)
            fCallBack(mData.data)
        end)
    else
        record.warning(string.format("KS2GSProfileRemoteEvent error Pid:%s Key:%s Fun:%s", iPid, sFunc))
    end
end

