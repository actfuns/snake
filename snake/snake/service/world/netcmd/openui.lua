--import module
local global = require "global"
local extend = require "base.extend"

local handlenpc = import(service_path("npc/handlenpc"))

function C2GSOpenScheduleUI(oPlayer,mData)
    oPlayer.m_oScheduleCtrl:GS2CSchedule()
end

function C2GSWeekSchedule(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local lWeekSchedule = oHuodongMgr:WeekScheduleList()
    oPlayer:Send("GS2CWeekSchedule", {weekschedule=lWeekSchedule})
end

function C2GSScheduleReward(oPlayer,mData)
    local rewardidx = mData["rewardidx"]
    oPlayer.m_oScheduleCtrl:GetReward(rewardidx)
end

function C2GSRewardDoublePoint(oPlayer, mData)
    oPlayer.m_oBaseCtrl:RewardDoublePoint()
end

function C2GSOpenInterface(oPlayer, mData)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:ClientOpen(oPlayer, mData.type)
end

function C2GSCloseInterface(oPlayer, mData)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:ClientClose(oPlayer, mData.type)
end

function C2GSOpenFBComfirm(oPlayer,mData)
    local iFuben = mData.fuben
    global.oFubenMgr:TryStartFuben(oPlayer,iFuben)
end

function C2GSUseAdvanceMap(oPlayer,mData)
    local itemid = mData.itemid
    if not itemid then return end
    local itemobj = oPlayer.m_oItemCtrl:HasItem(itemid)
    if not itemobj then return end
    itemobj:TrueUse2(oPlayer)
end

function C2GSOpenBox(oPlayer, mData)
    global.oItemHandler.m_oBoxMgr:TryOpenBox(oPlayer, mData.box_sid)
end

function C2GSQuickBuyItem(oPlayer, mData)
    oPlayer.m_oItemCtrl:QuickBuyItem(mData.sid, mData.amount)
end

function C2GSFindHDNpc(oPlayer, mData)
    local npcobj = global.oNpcMgr:GetGlobalNpc(5248)
    if not npcobj then return end
    local iMap = npcobj:MapId()
    local mPosInfo = npcobj:PosInfo()
    local iX = mPosInfo["x"]
    local iY = mPosInfo["y"]
    local oSceneMgr = global.oSceneMgr
    if not oSceneMgr:SceneAutoFindPath(oPlayer:GetPid(), iMap, iX, iY, npcobj:ID()) then
        npcobj:OpenHDSchedule(oPlayer)
    end
end

function C2GSFindGlobalNpc(oPlayer, mData)
    local npctype = mData.npctype
    if not npctype then
        return
    end
    local npcobj = global.oNpcMgr:GetGlobalNpc(npctype)
    if not npcobj then return end
    local iMap = npcobj:MapId()
    local mPosInfo = npcobj:PosInfo()
    local iX = mPosInfo["x"]
    local iY = mPosInfo["y"]
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:SceneAutoFindPath(oPlayer:GetPid(), iMap, iX, iY, npcobj:ID())
end

--元宝兑换货币
function C2GSExchangeCash(oPlayer, mData)
    local iMoneyType = mData.moneytype
    local iGoldCoin = mData.goldcoin
    oPlayer:ExchangeMoneyByGoldCoin(iMoneyType,iGoldCoin)
end

function C2GSXunLuo(oPlayer, mData)
    local iType = mData.type
    global.oSceneMgr:XunLuoChange(oPlayer, iType)
end
