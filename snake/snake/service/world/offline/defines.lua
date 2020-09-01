local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))

CNT_FRIEND = 50
DEGREE_PROTECT = 1000
DEGREE_MAX = 50000

RELATION_COUPLE = 1
RELATION_BROTHER = 2
RELATION_MASTER = 3
RELATION_ENGAGE = 4
RELATION_APPRENTICE = 5


--小于10000调用玩家方法
Func2No = {
    ["RewardSilver"] = 1001,
    ["AddTitle"] = 1002,
    ["RemoveTitles"] = 1003,
    ["SyncTitleName"] = 1004,
    ["RedeemCodeReward"] = 1005,
    ["DissolveEngage"] = 1006,
    ["SyncMarryCoupleName"] = 1007,
    ["DoForceDivorce"] = 1008,
    ["OnSuccessDivorce"] = 1009,

    ["BanPlayerChat"] = 10001,
    ["FinePlayerMoney"] = 10002,
    ["RenamePlayer"] = 10003,
    ["RemovePlayerItem"] = 10004,
    ["RenameSummon"] = 10005,
    ["ForceLeaveTeam"] = 10006,
    ["ForceChangeScene"] = 10007,
    ["OnlineChangeScene"] = 10008,
    
    ["PayForGold"] = 11001,
    ["PayForHuodongCharge"] = 11002,
    ["HuodongReward"] = 11003,
    ["FixVigor"] = 11004,
    ["FixRecovery"] = 11005,
    ["FixRmSummon"] = 11006,
    ["AuctionReturnMoney"] = 11007,
    ["FixSummonAdvance"] = 11008,
    
}

function GetFuncNo(sFunc)
    return Func2No[sFunc]
end

function GetFuncByNo(iFuncNo)
    for sFunc,iNo in pairs(Func2No) do
        if iFuncNo == iNo then
            return sFunc
        end
    end
end


mOnlineExecute = {}
mOnlineExecute.PayForGold = function(oPlayer, iAmount, lArgs, sProductKey)
    global.oPayMgr.m_oPayCb:pay_for_gold(oPlayer:GetPid(), iAmount, lArgs, sProductKey)
end

mOnlineExecute.PayForHuodongCharge = function(oPlayer, iAmount, lArgs, sProductKey)
    global.oPayMgr.m_oPayCb:pay_for_huodong_charge(oPlayer:GetPid(), iAmount, lArgs, sProductKey)
end

mOnlineExecute.HuodongReward = function(oPlayer, sHDName,iReward)
    local oHD =  global.oHuodongMgr:GetHuodong(sHDName)
    if oHD then
        oHD:Reward(oPlayer:GetPid(),iReward)
    end
end

mOnlineExecute.FixVigor = function(oPlayer, iValue, sReason, mMail)
    local iSub = math.min(iValue, oPlayer:GetVigor())
    if iSub > 0 then
        oPlayer:AddVigor(-iSub, sReason)
        if mMail then
            global.oMailMgr:SendMail(0, "系统", oPlayer:GetPid(), mMail)
        end
    end
end

mOnlineExecute.FixRecovery = function (oPlayer)
    for _,oSumm in pairs(oPlayer.m_mRecoveryCtrl.m_SummonID) do
        if oSumm:TypeID() == 2028 then
            oPlayer.m_mRecoveryCtrl:RemoveSum(oSumm)
            break
        end
    end
end

mOnlineExecute.FixRmSummon = function (oPlayer, mMail)
    for _,oSumm in pairs(oPlayer.m_oSummonCtrl.m_mSummons) do
        if oSumm:TypeID() == 2028 then
            oPlayer.m_oSummonCtrl:RemoveSummon(oSumm)
            local oItem = global.oItemLoader:ExtCreate("1003(Value=100)")
            global.oMailMgr:SendMail(0, "系统", oPlayer:GetPid(), mMail, 0, {oItem})
            return
        end
    end
end

mOnlineExecute.AuctionReturnMoney = function(oPlayer, iMoneyType, iPrice, sReason, sName, mMail, mReward)
    local iPid = oPlayer:GetPid()
    mReward = global.oAuction.m_oOperator:LoadRewardSaveData(mReward)
    global.oAuction.m_oOperator:ReturnMoneyByType(iPid, iMoneyType, iPrice, sReason, sName, mMail, mReward)
end

mOnlineExecute.FixSummonAdvance = function(oPlayer, iSummonTrano, iCurLevel, iBackLevel)
    if iCurLevel <= 0 then return end

    local iPid = oPlayer:GetPid()
    local mTraceNo = {iPid, iSummonTrano}
    local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo(mTraceNo)
    if not oSummon then
        print("FixSummonAdvance--debug---- %s %s %s %s", iPid, iSummonTrano, iCurLevel, iBackLevel)            
        return
    end

    oSummon:SetAdvanceLevel(iCurLevel)
    if iBackLevel and iBackLevel > 0 then
        local mConfig = global.oSummonMgr:GetAdvanceConfig(oSummon:Type(), iBackLevel)
        local iGrow = mConfig["grow"]
        oSummon:AddGrow(-iGrow)
        for _,sAttr in pairs({"attack", "defense", "health", "mana", "speed"}) do
            local iAttribute = mConfig[sAttr]
            local mMaxAptitude = oSummon:GetData("maxaptitude", {}) 
            local mCurAptitude = oSummon:GetData("curaptitude", {})
            mMaxAptitude[sAttr] = mMaxAptitude[sAttr] - iAttribute
            mCurAptitude[sAttr] = mCurAptitude[sAttr] - iAttribute
            oSummon:SetData("maxaptitude", mMaxAptitude)
            oSummon:SetData("curaptitude", mCurAptitude)
        end
        if oSummon:GetOwner() then
            global.oScoreCache:Dirty(oSummon:GetOwner(), "summonctrl")
        end
        global.oScoreCache:SummonDirty(oSummon:ID())
        oSummon:Setup()
        oSummon:FullState()
        oSummon:Refresh() 
        oSummon:RefreshOwnerScore()

        local mData = {}
        mData["createtime"] = get_time()
        mData["title"] = "神兽进阶异常返还"
        mData["context"] = "\n亲爱的玩家：\n 由于神兽进阶功能异常，导致属性可以反复叠加，目前已经修复，并且扣减了异常叠加的属性，现在将重复进阶扣除的物品返还给您，请在附件领取。给您造成的不便深表歉意，\n 感谢您一直以来对<<#gamename>>的支持与厚爱！"
        mData["keeptime"] = 30*24*3600
        mData["readtodel"] = 0
        mData["autoextract"] = 1
        mData["icon"] = "h7_mail_unopened"
        mData["openicon"] = "h7_mail_opened"

        local oItem = global.oItemLoader:Create(11176)
        local lType = {5003, 5006}
        if table_in_list(lType, oSummon:TypeID()) then
            oItem:SetAmount(25)
        else
            oItem:SetAmount(20)
        end
        global.oMailMgr:SendMail(0, "系统", iPid, mData, 0, {oItem})
        print("FixSummonAdvance--back---- %s %s %s %s", iPid, iSummonTrano, iCurLevel, iBackLevel)            
    end
    print("FixSummonAdvance--success---- %s %s %s %s", iPid, iSummonTrano, iCurLevel, iBackLevel)            
end


