local global = require "global"
local res = require "base.res"
local record = require "public.record"
local interactive = require "base.interactive"

local defines = import(service_path("auction.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local loadsumm = import(service_path("summon.loadsummon"))

function NewOperator(...)
    local o = COperator:New(...)
    return o
end


COperator = {}
COperator.__index = COperator
inherit(COperator, logic_base_cls())

function COperator:New(oTaskObj)
    local o = super(COperator).New(self)
    o.m_oTaskObj = oTaskObj
    o:Init()
    return o
end

function COperator:Init()
    self.m_mOpenPlayers = {}
end

function COperator:FilterProxyItem(iCat, iSub)
    local oAuction = self.m_oTaskObj
    local lToday, lNextDay = {}, {}
    local iToday = get_dayno()
    local mData = oAuction:GetCatalogInfo(iCat, iSub) or {}
    for iProxy, _ in pairs(mData) do
        local oProxy = oAuction:GetProxyById(iProxy)
        if not oProxy then
            goto continue
        end
        if oProxy:GetTableKey("is_open") ~= 1 then
            goto continue
        end
        if get_dayno(oProxy:GetViewTime()) <= iToday then
            table.insert(lToday, oProxy)
        else
            table.insert(lNextDay, oProxy)
        end
        ::continue::
    end
    return #lToday > 0 and lToday or lNextDay
end

function COperator:OpenBuyAuction(oPlayer, iCat, iSub, iPage)
    local lProxy = self:FilterProxyItem(iCat, iSub)
    local lResult, iPid = {}, oPlayer:GetPid()
    local iStart, iEnd = defines.PageRange(iPage)
    for i=iStart, iEnd, 1 do
        local oProxyItem = lProxy[i]
        if not oProxyItem then break end
        table.insert(lResult, oProxyItem:PackSimpleInfo(iPid))
    end

    local mNet = {}
    mNet.cat_id = iCat
    mNet.sub_id = iSub
    mNet.sell_list = lResult
    mNet.total = #lProxy
    mNet.page = iPage
    oPlayer:Send("GS2COpenAuction", mNet)

    self:AddOpenUIPlayer(iPid)
end

function COperator:ValidMoneyByType(oPlayer, iMoneyType, iPrice)
    if iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        return oPlayer:GetProfile():TrueGoldCoin() >= iPrice
    elseif iMoneyType == gamedefines.MONEY_TYPE.GOLD then
        return oPlayer:ValidGold(iPrice, {cancel_tip=1})
    end
    return false
end

function COperator:ResumeMoneyByType(oPlayer, iMoneyType, iPrice, sReason)
    if iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        oPlayer:GetProfile():ResumeTrueGoldCoin(iPrice, sReason, {cancel_rank=1})
    elseif iMoneyType == gamedefines.MONEY_TYPE.GOLD then
        oPlayer:ResumeGold(iPrice, sReason)
    end

    record.log_db("huodong", "auction", {info = {
        action = "拍卖出价",
        pid = oPlayer:GetPid(),
        reason = sReason,
        price = iPrice,
        money = gamedefines.MONEY_NAME[iMoneyType],
    }})
end 

function COperator:ReturnMoneyByType(iPid, iMoneyType, iPrice, sReason, sName, mMail, mReward)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        if iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN and iPrice > 0 then
            oPlayer:ChargeGold(iPrice, sReason)
        elseif iMoneyType == gamedefines.MONEY_TYPE.GOLD and iPrice > 0 then
            oPlayer:RewardGold(iPrice, sReason)
        end
        if mMail and sName then
            global.oMailMgr:SendMailNew(0, sName, iPid, mMail, mReward)
        end
        local mLogData = {
            action = "发放货币或者道具-在线",
            money = gamedefines.MONEY_NAME[iMoneyType],
            price = iPrice,
            reason = sReason,
            pid = iPid,
        }
        record.log_db("huodong", "auction", {info = mLogData})
    else
        local mSaveReward = self:PackRewardSaveData(mReward)
        local lArgs = {iMoneyType, iPrice, sReason, sName, mMail, mSaveReward}
        global.oPubMgr:OnlineExecute(iPid, "AuctionReturnMoney", lArgs)
        local mLogData = {
            action = "发放货币或者道具-离线",
            money = gamedefines.MONEY_NAME[iMoneyType],
            price = iPrice,
            reason = sReason,
            pid = iPid,
        }
        record.log_db("huodong", "auction", {info = mLogData})
    end
end

function COperator:PackRewardSaveData(mReward)
    if not mReward then return end

    local mSaveReward = {}
    for sKey, lReward in pairs(mReward) do
        mSaveReward[sKey] = {}
        for _, oReward in ipairs(lReward) do
            table.insert(mSaveReward[sKey], oReward:Save())
        end
    end
    return mSaveReward
end

function COperator:LoadRewardSaveData(mSaveReward)
    if not mSaveReward then return end

    local mReward = {}
    for sKey, lReward in pairs(mSaveReward) do
        mReward[sKey] = {}
        for _, mSave in ipairs(lReward) do
            if sKey == "summons" then
                local oNewSummon = loadsumm.LoadSummon(mSave.sid, mSave)
                table.insert(mReward[sKey], oNewSummon)
            elseif sKey == "items" then
                local oNewItem = global.oItemLoader:LoadItem(mSave.sid, mSave)
                table.insert(mReward[sKey], oNewItem)
            end
        end
    end
    return mReward
end

function COperator:AuctionBid(oPlayer, id, iPrice)
    local oAuction = self.m_oTaskObj
    local oProxy = oAuction:GetProxyById(id)
    if not oProxy then
        self:Notify(oPlayer:GetPid(), 4001)
        return
    end

    if oProxy:GetTableKey("is_open") == 0 then
        self:Notify(oPlayer:GetPid(), 4001)
        return
    end

    if not oProxy:InPriceTime() then
        self:Notify(oPlayer:GetPid(), 4002)
        return
    end

    local iMoneyType = oProxy:GetMoneyType()
    if not gamedefines.MONEY_NAME[iMoneyType] then
        self:Notify(oPlayer:GetPid(), 4003)
        return
    end

    if iPrice < oProxy:GetMinBidPrice() then
        local mReplace = {
            money = gamedefines.MONEY_NAME[iMoneyType],
            amount = oProxy:GetBidderPrice() or oProxy:GetPrice(),
        }
        self:Notify(oPlayer:GetPid(), 4004, mReplace)
        oPlayer:Send("GS2CRefreshSellUnit", {
            unit = oProxy:PackSimpleInfo(oPlayer:GetPid()),
        })
        return
    end

    if not self:ValidMoneyByType(oPlayer, iMoneyType, iPrice) then
        local mReplace = {
            money = gamedefines.MONEY_NAME[iMoneyType],
        }
        self:Notify(oPlayer:GetPid(), 5001, mReplace)
        return
    end

    if oPlayer:GetPid() == oProxy:GetOwner() then
        self:Notify(oPlayer:GetPid(), 4006)
        return
    end

    if oPlayer:GetPid() == oProxy:GetBidder() then
        self:Notify(oPlayer:GetPid(), 4007)
        return
    end

    if oPlayer:GetPid() == oProxy:GetProxyBidder() then
        self:Notify(oPlayer:GetPid(), 4008)
        return
    end

    oProxy:TryGenProxyBidders()
    self:AuctionBidPrice(oPlayer, oProxy, iPrice)
    self:CheckProxyPrice(oProxy)
end

function COperator:AuctionBidPrice(oPlayer, oProxy, iPrice)
    local iMoneyType = oProxy:GetMoneyType()
    local iPid = oPlayer:GetPid()
    self:ReturnMoney2Bidder(oProxy)
    self:ResumeMoneyByType(oPlayer, iMoneyType, iPrice, "拍卖出价"..oProxy:LogName())
    oProxy:SetBidderPrice(iPrice)
    oProxy:SetBidder(iPid)
    self:Notify(iPid, 4005)
    oPlayer:Send("GS2CRefreshSellUnit", {unit=oProxy:PackSimpleInfo(iPid)})
    oProxy:PriceChangeNotifyFollow()
end

function COperator:ReturnMoney2Bidder(oProxy)
    local iBidder = oProxy:GetBidder()
    if not iBidder then return end
    
    local iMoneyType = oProxy:GetMoneyType()
    local iBidPrice = oProxy:GetBidderPrice() or oProxy:GetPrice()

    if iBidder == oProxy:GetProxyBidder() then
        oProxy:AddProxyBidderPrice(iBidPrice)
    else
        self:ReturnMoney2Pid(oProxy, iBidder, iBidPrice, 1005, "竞价返还"..oProxy:LogName())
    end

    local oBidder = global.oWorldMgr:GetOnlinePlayerByPid(iBidder)
    if oBidder then
        oBidder:Send("GS2CRefreshSellUnit", {
            unit = oProxy:PackSimpleInfo(iBidder),
        })
    end
end

function COperator:ReturnMoney2Pid(oProxy, iPid, iPrice, iMail, sReason)
    local iMoneyType = oProxy:GetMoneyType()
    local mMail, sName = global.oMailMgr:GetMailInfo(iMail)
    local mReplace = {
        amount = iPrice, 
        money = gamedefines.MONEY_NAME[iMoneyType],
        item = oProxy:GetName(),
    }
    mMail.context = global.oToolMgr:FormatColorString(mMail.context, mReplace)
    self:ReturnMoneyByType(iPid, iMoneyType, iPrice, sReason, sName, mMail)
end

function COperator:CheckProxyPrice(oProxy)
    if not oProxy:InPriceTime() then return end

    local iBidder = oProxy:GetBidder()
    local iProxyBidder = oProxy:GetProxyBidder()
    if not iProxyBidder or iProxyBidder == iBidder then
        return
    end

    local iProxyPrice = oProxy:GetProxyBidderPrice()
    if not iProxyPrice then return end

    if iProxyPrice <= (oProxy:GetBidderPrice() or oProxy:GetPrice()) then
        oProxy:SetProxyBidder(nil)
        oProxy:SetProxyBidderPrice(nil)
        local sReason = "代理竞价被超出"..oProxy:LogName()
        self:ReturnMoney2Pid(oProxy, iProxyBidder, iProxyPrice, 1005, sReason)

        local oProxyBidder = global.oWorldMgr:GetOnlinePlayerByPid(iProxyBidder)
        if oProxyBidder then
            oProxyBidder:Send("GS2CRefreshSellUnit", {
                unit = oProxy:PackSimpleInfo(iProxyBidder),
            })
        end
        return
    end

    local iPrice = math.min(iProxyPrice, oProxy:GetMinBidPrice())
    self:ReturnMoney2Bidder(oProxy)
    oProxy:AddProxyBidderPrice(-iPrice)
    oProxy:SetBidderPrice(iPrice)
    oProxy:SetBidder(iProxyBidder)
    oProxy:PriceChangeNotifyFollow()
end

function COperator:ValidSetProxyPrice(oPlayer, oProxy, iPrice)
    if not oProxy or not iPrice then return 7001 end

    if oProxy:GetTableKey("is_open") == 0 then
        return 7001 
    end

--    if not oProxy:InShowTime() and not oProxy:InPriceTime() then
--        return 5007
--    end

    local iMinProxyPrice = oProxy:GetMinProxyPrice()
    if iPrice < iMinProxyPrice then
        return 5003
    end

    if oProxy:GetOwner() == oPlayer:GetPid() then
        return 5008
    end

    local iMoneyType = oProxy:GetMoneyType()
    if not gamedefines.MONEY_NAME[iMoneyType] then
        return 5001, {money=gamedefines.MONEY_NAME[iMoneyType]}
    end

--    local iBidder = oProxy:GetBidder()
--    if iBidder == oPlayer:GetPid() then
--        return 5009
--    end

    return 1
end

function COperator:SetProxyPrice(oPlayer, id, iPrice)
    local oAuction = global.oAuction
    local iPid = oPlayer:GetPid()
    local oProxy = oAuction:GetProxyById(id)

    local iRet, mReplace = self:ValidSetProxyPrice(oPlayer, oProxy, iPrice)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    if oProxy:InShowTime() or oProxy:InViewTime() then
        self:SetProxyPriceInShowTime(oPlayer, oProxy, iPrice)
    elseif oProxy:InPriceTime() then
        self:SetProxyPriceInPriceTime(oPlayer, oProxy, iPrice)
    end
end

function COperator:SetProxyPriceInShowTime(oPlayer, oProxy, iPrice)
    local iPid = oPlayer:GetPid()
    local iMoneyType = oProxy:GetMoneyType()
    local sReason = "公示期设置代理竞价"..oProxy:LogName()
    local iTruePrice = iPrice - oProxy:GetProxyPrice(iPid)

    if iTruePrice == 0 then
        self:Notify(iPid, 5010)
        return
    end
    if iTruePrice > 0 and not self:ValidMoneyByType(oPlayer, iMoneyType, iTruePrice) then
        self:Notify(iPid, 5001, {money=gamedefines.MONEY_NAME[iMoneyType]})
        return
    end

    if iTruePrice < 0 then
        oProxy:AddProxyBidder(iPid, iTruePrice)
        self:ReturnMoneyByType(iPid, iMoneyType, -iTruePrice, sReason)
    else
        self:ResumeMoneyByType(oPlayer, iMoneyType, iTruePrice, sReason)
        oProxy:AddProxyBidder(iPid, iTruePrice)
    end

    oPlayer:Send("GS2CRefreshSellUnit", {unit=oProxy:PackSimpleInfo(iPid)})
    self:Notify(iPid, 5004)
end

function COperator:SetProxyPriceInPriceTime(oPlayer, oProxy, iPrice)
    oProxy:TryGenProxyBidders()

    local iProxyBidder = oProxy:GetProxyBidder()
    local iPid = oPlayer:GetPid()
    local iBidder = oProxy:GetBidder()
    if iBidder == iPid and iPid ~= iProxyBidder then
        self:Notify(iPid, 5009)
        return
    end

    local iProxyPrice = oProxy:GetProxyBidderPrice() or 0
    local iBidderPrice = oProxy:GetBidderPrice() or oProxy:GetPrice()
    local iTotal = iProxyPrice + iBidderPrice
    local iMoneyType = oProxy:GetMoneyType()
    local sReason = "竞价期设置代理竞价"..oProxy:LogName()
    if iPid == iProxyBidder then
        local iTruePrice = iPrice - (iProxyPrice + iBidderPrice)
        if iTruePrice <= 0 then
            self:Notify(iPid, 5002)
        else
            if not self:ValidMoneyByType(oPlayer, iMoneyType, iTruePrice) then
                self:Notify(iPid, 5001, {money=gamedefines.MONEY_NAME[iMoneyType]})
                return
            end
            self:ResumeMoneyByType(oPlayer, iMoneyType, iTruePrice, sReason)
            oProxy:AddProxyBidderPrice(iTruePrice)
            self:CheckProxyPrice(oProxy)
            oPlayer:Send("GS2CRefreshSellUnit", {unit=oProxy:PackSimpleInfo(iPid)})
            self:Notify(iPid, 5004)
        end
        return
    end

    if not self:ValidMoneyByType(oPlayer, iMoneyType, iPrice) then
        self:Notify(iPid, 5001, {money=gamedefines.MONEY_NAME[iMoneyType]})
        return
    end
    self:ResumeMoneyByType(oPlayer, iMoneyType, iPrice, sReason)

    if iProxyPrice > 0 then
        if iPrice <= iTotal then
            oProxy:AddProxyBidderPrice(iBidderPrice)
            oProxy:SetBidder(iPid)
            oProxy:SetBidderPrice(iPrice)
            self:CheckProxyPrice(oProxy)
        else
            oProxy:SetBidder(iProxyBidder)
            oProxy:SetBidderPrice(iTotal)
            oProxy:SetProxyBidder(iPid)
            oProxy:SetProxyBidderPrice(iPrice)
            self:CheckProxyPrice(oProxy)
        end
    else
        oProxy:SetProxyBidder(iPid)
        oProxy:SetProxyBidderPrice(iPrice)
        self:CheckProxyPrice(oProxy)
    end

    oPlayer:Send("GS2CRefreshSellUnit", {unit=oProxy:PackSimpleInfo(iPid)})
    self:Notify(iPid, 5004)
end

function COperator:RewardTrueItem(oPlayer, oProxy)
    local oItem = oProxy.m_oDataCtrl
    local iSid, mItem = oItem:SID(), oItem:Save()
    local iAmount = oProxy:GetAmount()
    local oNewItem = global.oItemLoader:LoadItem(iSid, mItem)
    oNewItem:SetAmount(iAmount)
    return {oNewItem}
end

function COperator:RewardTrueSumm(oPlayer, oProxy)
    local oSummon = oProxy.m_oDataCtrl
    local iSid, mSummon = oSummon:TypeID(), oSummon:Save()
    local iAmount = oProxy:GetAmount()
    local oNewSummon = loadsumm.LoadSummon(iSid, mSummon)
    return {oNewSummon}
end

function COperator:RewardAuction(oProxy)
    local iPid = oProxy:GetBidder()
    if not iPid then return end

    local mReward = {}
    if oProxy:Type() == defines.PROXY_TYPE_ITEM then
        mReward.items = self:RewardTrueItem(oPlayer, oProxy)
    else
        mReward.summons = self:RewardTrueSumm(oPlayer, oProxy)
    end

    local iMoneyType = oProxy:GetMoneyType()
    local sReason = "拍卖结束"..oProxy:LogName()
    local mMail, sName = global.oMailMgr:GetMailInfo(1006)
    local iPrice = oProxy:GetProxyBidderPrice() or 0
    local mReplace = {
        item = oProxy:GetName(),
        amount = oProxy:GetBidderPrice(),
        money = gamedefines.MONEY_NAME[iMoneyType],
    }

    if oProxy:GetProxyBidder() == iPid then
        if iPrice > 0 then
            mReplace.ret = iPrice
            mMail.context = mMail.context.."您竞拍成功剩余的#ret#money已经返还到您的背包"
        end
        oProxy:SetProxyBidder(nil)
        oProxy:SetProxyBidderPrice(nil)
    end
    mMail.context = global.oToolMgr:FormatColorString(mMail.context, mReplace)
    self:ReturnMoneyByType(iPid, iMoneyType, iPrice, sReason, sName, mMail, mReward)
end

function COperator:ToggleFollow(oPlayer, id)
    local oAuction = self.m_oTaskObj
    local oProxy = oAuction:GetProxyById(id)
    if not oProxy then return end

    if oProxy:GetTableKey("is_open") == 0 then
        return
    end

    local iPid = oPlayer:GetPid()
    if oProxy:IsFollow(iPid) then
        oProxy:RemoveFollowPid(iPid)
    else
        oProxy:AddFollowPid(iPid)
    end
    oPlayer:Send("GS2CRefreshSellUnit", {unit=oProxy:PackSimpleInfo(iPid)})
end

function COperator:TryRemoveProxy(oProxy)
    if oProxy:GetAmount() > 0 then return end
    if oProxy:GetBidderPrice() then return end
    if oProxy:GetOwner() > 0 then return end

    local oAuction = global.oAuction
    oAuction:RemoveProxy(oProxy:GetID())
end

function COperator:SendAuctionDetail(oPlayer, id)
    local oAuction = self.m_oTaskObj
    local oProxy = oAuction:GetProxyById(id)
    if not oProxy then return end

    local mNet
    if oProxy:Type() == defines.PROXY_TYPE_ITEM then
        mNet = {
            id = id,
            type = oProxy:Type(),
            itemdata = oProxy.m_oDataCtrl:PackItemInfo(),
        }
    else
        mNet = {
            id = id,
            type = oProxy:Type(),
            summondata = oProxy.m_oDataCtrl:SummonInfo(),
        }
    end
    oPlayer:Send("GS2CAuctionDetail", mNet)
end

function COperator:ClickLink(oPlayer, id)
    local oAuction = self.m_oTaskObj
    local oProxy = oAuction:GetProxyById(id)
    if not oProxy then
        self:Notify(oPlayer:GetPid(), 7001)
        return
    end
    local iStatus = 0
    if oProxy:InShowTime() then iStatus = 1 end
    if oProxy:InPriceTime() then iStatus = 2 end
    if iStatus == 0 then
        self:Notify(oPlayer:GetPid(), 8001)
        return
    end

    local iCat, iSub = oProxy:GetCatalog()
    local mData = oAuction:GetCatalogInfo(iCat, iSub) or {}
    local lResult, iPage, iTotal = self:GetShowLinkRange(mData, iStatus, id)
    if #lResult <= 0 then
        self:Notify(oPlayer:GetPid(), 8001)
        return
    end
    local lSell, mNet = {}, {}
    for _, oProxy in pairs(lResult) do
        table.insert(lSell, oProxy:PackSimpleInfo())
    end
    mNet.cat_id = iCat
    mNet.sub_id = iSub
    mNet.sell_list = lSell
    mNet.total = iTotal
    mNet.page = iPage
    mNet.status = iStatus
    mNet.target = id
    oPlayer:Send("GS2CShowLink", mNet)
end

function COperator:GetShowLinkRange(mData, iStatus, id)
    local lAll, idx, iTotal = {}, 0, 0
    for iProxy, _ in pairs(mData) do
        local oProxy = self.m_oTaskObj:GetProxyById(iProxy)
        if (iStatus==1 and oProxy:InShowTime()) or (iStatus==2 and oProxy:InPriceTime()) then
            iTotal = iTotal + 1
            if iProxy == id then idx = iTotal end
            table.insert(lAll, oProxy)
        end
    end
    if idx ~= 0 then
        local lResult = {}
        local iPage = math.ceil(idx / defines.PAGE_AMOUNT)
        local iStart, iEnd = defines.PageRange(iPage)
        for i = iStart, iEnd, 1 do
            if not lAll[i] then break end
            table.insert(lResult, lAll[i])
        end
        return lResult, iPage, iTotal
    end

    return {}, 0, 0
end

function COperator:AddOpenUIPlayer(iPid)
    self.m_mOpenPlayers[iPid] = 1
end

function COperator:DelOpenUIPlayer(iPid)
    self.m_mOpenPlayers[iPid] = nil
end

function COperator:GetOpenUIPlayers()
    return self.m_mOpenPlayers
end

function COperator:BroadCast(sMessage, mData)
    interactive.Send(".broadcast", "channel", "SendChannel2Targets", {
        message = sMessage,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = mData,
        targets = self:GetOpenUIPlayers(),
    })
end

function COperator:GetPlayerUnit(iPid)
    return self.m_oTaskObj:GetPlayerUnit(iPid)
end

function COperator:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:FormatMsg(iChat, mReplace)
    oNotifyMgr:Notify(iPid, sMsg)
end

function COperator:FormatMsg(iChat, mReplace)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iChat, {"auction"})
    if mReplace then
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
    end
    return sMsg
end

function COperator:GetAuctionTable()
    return res["daobiao"]["auction"]
end

