--import module
local global  = require "global"
local extend = require "base.extend"

local huodongbase = import(service_path("huodong.huodongbase"))
local itemdefines = import(service_path("item/itemdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))

local EventFunc = {
    ["放妖"] = "TriggerFengYao",
    ["放妖王"] = "TriggerFengYaoWang",
    ["副本"] = "TriggerSceneMap",
}


local mEventType = {[11076] = "normalevent", [11077] = "advancevent"}
local mEvent1 = {["金币"] = "1001", ["银币"] = "1002", ["物品道具"] = "1003"}
local mEvent2 = {["金币"] = "2001", ["银币"] = "2002", ["物品道具"] = "2003"}
local mEvent={[11076]=mEvent1,[11077]=mEvent2}

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "挖宝"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:Init()
    self.m_sName = "treasure"
    self.m_iScheduleID = 1004
    self:TryStartRewardMonitor()
end

function CHuodong:RewardGold(oPlayer, iGold, mArgs)
    mArgs = mArgs or {}
    mArgs.cancel_tip = true
    oPlayer:RewardGold(iGold, self.m_sName, mArgs)
end

function CHuodong:RewardSilver(oPlayer, iSliver, mArgs)
    mArgs = mArgs or {}
    mArgs.cancel_tip = true
    if iSliver>0 then
        oPlayer:RewardSilver(iSliver, self.m_sName, mArgs)
    end
end

function CHuodong:RamdomSceneIdForTreasureMap(iMapType)
    local res = require "base.res"
    local mMapList = {}
    if res["daobiao"]["scenegroup"][itemdefines.TREASUREMAP_SCENEGROUP[iMapType]] then
        mMapList = res["daobiao"]["scenegroup"][itemdefines.TREASUREMAP_SCENEGROUP[iMapType]]
    else
        return 101000
    end
    mMapList = mMapList["maplist"]
    return mMapList[math.random(#mMapList)]
end

function CHuodong:IsPlayerOnTrulyScene(iPid,iSceneId)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return false
    end
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iSceneId)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    return oNowScene:MapId() == iSceneId
end

function CHuodong:CheckCanContinueFindTreasure(iMapType,sLastTreasureEventType)
    return (sLastTreasureEventType ~= "副本")
end

function CHuodong:StartTreasure(oPlayer, mArgs)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:QueryPos(oPlayer.m_iPid,function(mData)
        if self:IsPlayerOnTrulyScene(oPlayer.m_iPid, mArgs["mapid"]) and (math.abs(math.modf(mArgs["pos_x"]) - math.modf(mData.pos_info.x)) <= 2 and math.abs(math.modf(mArgs["pos_y"]) - math.modf(mData.pos_info.y)) <= 2) then
            local itemid = mArgs["itemid"]
            local itemobj = oPlayer:HasItem(itemid)
            if not itemobj then
                return
            end
            local iCostAmount = itemobj:GetUseCostAmount()
            itemobj:AddAmount(-iCostAmount,"itemuse",{["refresh"]=1,["owner"] = oPlayer})
            local sTreasureEvent = self:RandomTreasureEvent(oPlayer, mArgs["sid"])
            local mRewardDataResult = self:_StartReward(oPlayer, mArgs["sid"], sTreasureEvent, itemobj:IsBind())
            oPlayer:MarkGrow(41)
            mRewardDataResult["reward_type"] = sTreasureEvent
            local iMapType = mArgs["maptype"]
            local iSid = mArgs["sid"]
            local func = function (oPlayer,mData)
                _CheckCanContinueFindTreasure(oPlayer,iMapType,sTreasureEvent,iSid)
            end

            local oCbMgr = global.oCbMgr
            oCbMgr:SetCallBack(oPlayer:GetPid(),"GS2CStartShowRewardByType",mRewardDataResult,nil,func)
            global.oRankMgr:PushDataToEveryDayRank(oPlayer, "treasure_find", {cnt=1})
        else
            local oNotifyMgr = global.oNotifyMgr
            oNotifyMgr:Notify(oPlayer:GetPid(),"挖宝位置不对哦！")
        end
    end)
end

function CHuodong:RandomTreasureEvent(oPlayer,iSid)
    local res = require"base.res"
    local mData = res["daobiao"]["huodong"][self.m_sName][mEventType[iSid]]
    assert(mData,string.format("没有配置 %s 的触发事件", mEventType[iSid]))
    local mEventTbl = {}
    for key,value in pairs(mData) do
        table.insert(mEventTbl,{["key"] = key,["weight"] = value.weight})
    end
    local iTotalWeight = itemdefines.TREASUREEVENT_TOTOALWEIGHT
    local iTorrent = math.random(iTotalWeight)
    local function cmp(a,b)
        return a.weight < b.weight
    end
    table.sort(mEventTbl,cmp)
    local sTargetEventType
    local iLastWeight = 0
    for key,value in pairs(mEventTbl) do
        if (value["weight"]+iLastWeight) >= iTorrent and iTorrent > iLastWeight then
            sTargetEventType = value.key
            break
        else
            iLastWeight = iLastWeight + value["weight"]
        end
    end
    --sTargetEventType = "物品道具"
    assert(sTargetEventType,string.format("藏宝图随机事件出错，SID为 %d ,随机权重为 %d",iSid,iTorrent))
    return sTargetEventType
end

function CHuodong:TriggerFengYao(oPlayer,iMapId, sEventType)
    local oHuodongMgr = global.oHuodongMgr
    local oFengYao = oHuodongMgr:GetHuodong("fengyao")
    local iTreasureMapId = oFengYao:TriggerFengYao(oPlayer,{["from_who"] = "treasure"})
    self:SendSceneChuanwenMsg(oPlayer:GetName(), iTreasureMapId, 1010) 
    global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1003))
end

function CHuodong:TriggerFengYaoWang(oPlayer,iMapId, sEventType)
    local oHuodongMgr = global.oHuodongMgr
    local oFengYao = oHuodongMgr:GetHuodong("fengyao")
    local iTreasureMapId = oFengYao:TriggerFengYaoWang(oPlayer,{["from_who"] = "treasure"})
    self:SendSceneChuanwenMsg(oPlayer:GetName(), iTreasureMapId, 1013)
    global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1004))
end

function CHuodong:RewardGold(oPlayer, iGold, mArgs)
    if iGold <= 0 then return end
    mArgs = mArgs or {}
    mArgs.cancel_chat = true 
    mArgs.cancel_tip = true
    oPlayer:RewardGold(iGold, self.m_sName, mArgs)
end

function CHuodong:RewardSilver(oPlayer, iSilver, mArgs)
    if iSilver <= 0 then return end
    mArgs = mArgs or {}
    mArgs.cancel_chat = true 
    mArgs.cancel_tip = true
    oPlayer:RewardSilver(iSilver, self.m_sName, mArgs)
end

function CHuodong:TriggerSceneMap(oPlayer,iMapSid)
    -- body
end

function CHuodong:_StartReward(oPlayer, iMapSid, sEventType, bBind)
    local sIdx = mEvent[iMapSid][sEventType] or ""
    if sIdx ~= "" then
        local mRewardData = self:Reward(oPlayer:GetPid(), sIdx, {item_bind = bBind})
        local mRewardDataResult = {}
        if sEventType == "金币" then
            local iGold = mRewardData["gold"]
            mRewardDataResult = {["moneyreward_info"] = {{["money_type"] = "金币", ["amount"] = iGold}}}
        elseif sEventType == "银币" then
            local  iSilver = mRewardData["silver"]
            mRewardDataResult = {["moneyreward_info"] = {{["money_type"] = "银币", ["amount"] = iSilver}}}
        elseif sEventType == "物品道具" then
            local  mData = {}
            for _, mItems in pairs(mRewardData["items"]) do 
                for _, oItem in ipairs(mItems["items"]) do
                    table.insert(mData,  {["sid"] = oItem:SID(),["amount"] = oItem:GetAmount()})
                end
            end
            mRewardDataResult["itemreward_info"] = mData
        end
        return mRewardDataResult
    else
        local func = self[EventFunc[sEventType]]
        assert(func,string.format("没有配置此类事件:%s",sEventType))
        return func(self,oPlayer,iMapSid,sEventType) or {}
    end
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs and mArgs.item_bind then
        for itemidx, mItems in pairs(mAllItems) do
            local lItems = mItems["items"]
            for _, oItem in ipairs(lItems) do
                oItem:Bind(oPlayer:GetPid())
            end
        end    
    end
    super(CHuodong).RewardItems(self, oPlayer, mAllItems, mArgs)
end

function _CheckCanContinueFindTreasure(oPlayer,iMapType,sTreasureEvent,iSid)
    local oHD  = global.oHuodongMgr:GetHuodong("treasure")
    if oHD:CheckCanContinueFindTreasure(iMapType, sTreasureEvent) then
        oPlayer:Send("GS2CContinueFindTreasure",{["sid"] = iSid})
    end
end

