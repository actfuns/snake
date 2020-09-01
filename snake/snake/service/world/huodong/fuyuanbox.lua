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
CHuodong.m_sTempName = "福缘宝箱"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mBoxes = {}
    o.m_mBoxRewards = {}
    o.m_mRewards = {}
    return o
end

function CHuodong:Init()
    if self:IsOpenFuYuanBox() then
        self:RefreshBoxes()
    end
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:NewHour(mNow)
    if self:IsOpenFuYuanBox() then
        self:RefreshBoxes()
    end
end

function CHuodong:RefreshBoxes()
    local mConfig = self:GetConfig()
    local sNum = mConfig.box_num
    local iOnlineCnt = global.oWorldMgr:GetOnlinePlayerCnt()
    local iNum =  math.floor(formula_string(sNum, { num = iOnlineCnt })) or 10

    for iBoxIdx, oBox in pairs(self.m_mBoxes) do
        self:RemoveTempNpc(oBox)
    end
    self.m_mBoxes = {}
    self.m_mBoxRewards = {}

    for idx=1, iNum do
        local oBox = self:InsertBoxToScene(idx)
        self.m_mBoxes[idx] = oBox

        local oBoxReward = self:GenBoxReward()
        self.m_mBoxRewards[idx] = oBoxReward
    end
end

function CHuodong:InsertBoxToScene(idx)
    local mConfig = self:GetConfig()
    local lMapPool = mConfig.map_pool
    local iNpc = mConfig.npc
    local iMap = extend.Random.random_choice(lMapPool)
    local lScene = global.oSceneMgr:GetSceneListByMap(iMap)
    local oScene = extend.Random.random_choice(lScene)
    local iX, iY = global.oSceneMgr:RandomPos2(oScene:MapId())
    local oNpc = self:CreateTempNpc(iNpc)
    oNpc.m_mPosInfo.x = iX
    oNpc.m_mPosInfo.y = iY
    oNpc.box_idx = idx
    self:Npc_Enter_Scene(oNpc, oScene:GetSceneId())
    return oNpc
end

function CHuodong:GenBoxReward()
    local mConfig = self:GetConfig()
    local mRewardInfo = self:GetItemRewardData(mConfig.random_reward)
    if not mRewardInfo then return end

    local mData = {}
    for _, mReward in pairs(mRewardInfo) do
        local iItemId = self:PickOutItemShape(mReward.sid)
        if iItemId then
            mData[iItemId] = table_deep_copy(mReward)
        end
    end
    return mData
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs then
        local mConfig = self:GetConfig()
        local mData = mAllItems[mConfig.random_reward]
        if mData then
            for _, oItem in ipairs(mData["items"]) do
                local iSid = oItem:SID()
                local iItemCnt = oItem:GetAmount()
                local mTmp = { id = iSid, amount = iItemCnt }
                table.insert(self.m_mRewards, mTmp)
            end
        end
    end
    super(CHuodong).RewardItems(self,oPlayer, mAllItems, mArgs)
end

function CHuodong:FindPathToFuYuanBox(oPlayer)
    if not self:IsOpenFuYuanBox() then
        return
    end

    local iPid = oPlayer:GetPid()

    local oBoxTarget
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene then
        for iBoxIdx, oBox in pairs(self.m_mBoxes) do
            if oBox:GetScene() == oScene:GetSceneId() then
                oBoxTarget = oBox
                break
            end
        end
    end

    if oBoxTarget then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1006))
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oBoxTarget)
    else
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1005))
    end
end

function CHuodong:OtherScript(iPid, oBox, s, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local sCmd = string.match(s,"^([$%a]+)")
    if not sCmd then return end
   
    local sArgs = string.sub(s, #sCmd+1, -1)
    if sCmd == "$openbox" then
        self:OpenBoxView(iPid, oBox)
    end
end

function CHuodong:OpenBoxView(iPid, oBox)
    local iBoxIdx = oBox.box_idx
        
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if not global.oToolMgr:IsSysOpen("FUYUAN_BOX", oPlayer) then
        return
    end

    self:GS2COpenFuYuanBoxView(oPlayer, iBoxIdx)
end

function CHuodong:IsOpenFuYuanBox(oPlayer)
    if oPlayer then
        return global.oToolMgr:IsSysOpen("FUYUAN_BOX", oPlayer, true)
    end
    return global.oToolMgr:IsSysOpen("FUYUAN_BOX")
end

function CHuodong:GetConfig()
    return res["daobiao"]["huodong"][self.m_sName]["config"][1]
end

function CHuodong:GS2COpenFuYuanBoxView(oPlayer, iBoxIdx)
    local mData = {
        box_idx = iBoxIdx,
        reward_ids = table_key_list(self.m_mBoxRewards[iBoxIdx]) or {}
    }
    oPlayer:Send("GS2COpenFuYuanBoxView", mData)
end

function CHuodong:C2GSOpenFuYuanBox(oPlayer, iBoxIdx, iTimes, bUseGoldCoin)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    local iRewardNo = mConfig.reward
    local oBox = self.m_mBoxes[iBoxIdx]
    if not oBox then
        oPlayer:Send("GS2CCloseFuYuanBoxView", {}) 
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1002)) --被别人打开了
        return
    end

    local iSize = oPlayer.m_oItemCtrl:GetCanUseSpaceSize()
    if iSize < iTimes+1 then
        global.oNotifyMgr:Notify(iPid, self:GetTextData(1007))
        return
    end

    if not self:FuYuanCost(oPlayer, iTimes, bUseGoldCoin) then
        return
    end

    self.m_mBoxes[iBoxIdx] = nil
    self:RemoveTempNpc(oBox)

    self:AddFuYuanCB(oPlayer, iBoxIdx, iTimes, iRewardNo)
    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "fuyuan_box", {cnt=iTimes})
end

function CHuodong:AddFuYuanCB(oPlayer, iBoxIdx, iTimes, iRewardNo)
    local iPid = oPlayer:GetPid()

    local mConfig = self:GetConfig()
    local mRewardInfo = self:GetItemRewardData(mConfig.random_reward)
    if not mRewardInfo then return end

    local mReward = self:ChooseRewardKey(nil, mRewardInfo)
    mReward = mReward and table_deep_copy(mReward)
    local iItemId = mReward and self:PickOutItemShape(mReward.sid)
    if not iItemId then return end

    local mData = {
        id = iItemId
    }
    oPlayer:Send("GS2CFuYuanLottery", mData)
    self:DoFuYuanReward(oPlayer, iBoxIdx, iTimes, iRewardNo, iItemId)
end

function CHuodong:FuYuanCost(oPlayer, iTimes, bUseGoldCoin)
    local mConfig = self:GetConfig()
    local iItemId = mConfig.open_item
    local iKeyCnt = oPlayer:GetItemAmount(iItemId)
    local iGoldCoin = oPlayer:GetGoldCoin()

    local iOneCostKey = 1
    local iStoreId = mConfig.store_id
    local mShopItem = res["daobiao"]["npcstore"]["data"][iStoreId]
    local bConfigCorrect = mShopItem and  mShopItem.virtual_coin and mShopItem.virtual_coin[1003]
    assert(bConfigCorrect, "fuyubox excel config cost error")
    local iOneCostGoldCoin = mShopItem.virtual_coin[1003].count
    local iTenDiscount = mConfig.ten_discount
    
    local iCostKey = 0
    local iCostGoldCoin = 0
    if iTimes == 1 then
        iCostKey = iOneCostKey
        if bUseGoldCoin and iKeyCnt == 0 then
            iCostKey = 0
            iCostGoldCoin = iOneCostGoldCoin
        end
    elseif iTimes == 10 then
        if iKeyCnt >= iTenDiscount then
            iCostKey = iTenDiscount
        elseif iKeyCnt > 0 and iKeyCnt < iTenDiscount then
            iCostKey = bUseGoldCoin and iKeyCnt or (iOneCostKey * iTenDiscount)
            if bUseGoldCoin then
                iCostGoldCoin = (iTenDiscount-iKeyCnt)*iOneCostGoldCoin
            end
        else
            if bUseGoldCoin then
                iCostGoldCoin = iTenDiscount * iOneCostGoldCoin               
            end
        end
    end

    if iKeyCnt < iCostKey and not (bUseGoldCoin and iKeyCnt == 0) then
        local sName = global.oItemLoader:GetItemNameBySid(iItemId)
        local sMsg = global.oToolMgr:FormatColorString(self:GetTextData(1003), {item = sName})
        global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
        return false
    end


    if bUseGoldCoin and not oPlayer:ValidGoldCoin(iCostGoldCoin) then
        return false
    end

    if iCostKey > 0 then
        oPlayer:RemoveItemAmount(iItemId, iCostKey, "福缘宝箱")
    end

    if iCostGoldCoin > 0 then
        oPlayer:ResumeGoldCoin(iCostGoldCoin, "福缘宝箱")
    end

    return true
end

function CHuodong:DoFuYuanReward(oPlayer, iBoxIdx, iTimes, iRewardNo, iMustItemId)
    self.m_mRewards = {}
    local iPid = oPlayer:GetPid()

    local mBoxInfo = self.m_mBoxRewards[iBoxIdx]
    local mMustItem = mBoxInfo[iMustItemId]

    local mArgs = {
        times = iTimes,
        box_idx = iBoxIdx,
        must_item = mMustItem,
        reward_idx = 1,
        cancel_tip = true,
        cancel_chat = true,
        cancel_quick = true,
        refresh = 1
    }
    for i=1, iTimes do
        mArgs.reward_idx = i
        self:Reward(iPid, iRewardNo, mArgs)
    end
    self:LogReward(iPid, iTimes)

    local mData = {
        times = iTimes,
        rewards = self.m_mRewards
    }
    oPlayer:Send("GS2CFuYuanBoxReward", mData)    
    -- oPlayer:Send("GS2CCloseFuYuanBoxView", {})     
end

function CHuodong:LogReward(iPid, iTimes)
    local mInfo = {
        pid = iPid,
        times = iTimes,
        reward = extend.Table.serialize(self.m_mRewards),
    }
    record.log_db("huodong", "fuyuanbox_reward", mInfo)
end

function CHuodong:ChooseRewardKey(oPlayer, mRewardInfo, itemidx, mArgs)
    local mConfig = self:GetConfig()
    if mConfig and itemidx == mConfig.random_reward and mArgs and mArgs.times then
        if mArgs.reward_idx == 1 then
            return mArgs.must_item
        end
    end
    return super(CHuodong).ChooseRewardKey(self, oPlayer, mRewardInfo, itemidx, mArgs)
end

function CHuodong:GetFixedItemSid()
    local mRewardInfo = self:GetItemRewardData(10001)[1]
    local iSid = tonumber(mRewardInfo.sid)
    return iSid, mRewardInfo.amount
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local iPid = mArgs[#mArgs]
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(iPid, [[
        101 - 刷新箱子 huodongop fuyuanbox 101
        ]])
    elseif iFlag == 101 then
        self:NewHour()
        global.oNotifyMgr:Notify(iPid, "刷新箱子")
    elseif iFlag == 102 then
        for idx, oBox in pairs(self.m_mBoxes) do
            local pos = oBox.m_mPosInfo
            local iScene = oBox:GetScene()
            local sSceneName = global.oSceneMgr:GetScene(iScene):GetName()
            local msg = string.format("第%s个: map = %s,  x = %s, y = %s", idx, sSceneName, pos.x, pos.y)
            oChatMgr:HandleMsgChat(oPlayer, msg)
        end
        global.oNotifyMgr:Notify(iPid, "请查看消息窗口")
    end
end
