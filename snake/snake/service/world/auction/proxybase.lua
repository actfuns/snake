local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))
local defines = import(service_path("auction.defines"))
local gamedefines = import(lualib_path("public.gamedefines"))


function NewProxyItem(...)
    local o = CProxy:New(...)
    o.m_iType = defines.PROXY_TYPE_ITEM
    return o
end

function NewProxySummon(...)
    local o = CProxy:New(...)
    o.m_iType = defines.PROXY_TYPE_SUMM
    return o
end

CProxy = {}
CProxy.__index = CProxy
inherit(CProxy, datactrl.CDataCtrl)

function CProxy:New(obj)
    local o = super(CProxy).New(self)
    o.m_ID = self:DispatchId()
    o.m_oDataCtrl = obj
    o:Init()
    return o
end

function CProxy:DispatchId()
    local oAuction = global.oAuction
    return oAuction:DispatchProxyId()
end

function CProxy:Init()
    self.m_mFollows = {}
    self.m_mProxyBidders = {}
end

function CProxy:Release()
    baseobj_safe_release(self.m_oDataCtrl)
    super(CProxy).Release(self)
end

function CProxy:Save()
    local mData = {}
    mData.datactrl = self.m_oDataCtrl:Save()
    mData.data = self.m_mData
    mData.follows = self.m_mFollows
    mData.proxy_bidders = self.m_mProxyBidders
    return mData
end

function CProxy:Load(mData)
    if not mData then return end

    self.m_mData = mData.data or {} 
    self.m_mFollows = table_to_int_key(mData.follows or {})
    self.m_mProxyBidders = table_to_int_key(mData.proxy_bidders or {})
end

function CProxy:Dirty()
    local oAuction = global.oAuction
    local oUnit = oAuction:GetPlayerUnit(self:GetOwner())
    oUnit:Dirty()
end

function CProxy:GetID()
    return self.m_ID
end

function CProxy:Type()
    return self.m_iType
end

function CProxy:SID()
    if self:Type() == defines.PROXY_TYPE_ITEM then
        return self.m_oDataCtrl:SID()
    else
        return self.m_oDataCtrl:TypeID()
    end
end

function CProxy:SetSys(idx)
    self:SetData("sys", idx)
    self:Dirty()
end

function CProxy:GetSys()
    return self:GetData("sys")
end

function CProxy:SetOwner(iPid)
    self:SetData("owner", iPid)
    self:Dirty()
end

function CProxy:GetOwner()
    return self:GetData("owner", 0)
end

function CProxy:InitTime(iViewTime)
    self:SetData("view_time", iViewTime)

    local mInfo = self:GetTableData()
    local iShowTime = iViewTime + mInfo.show_time*3600
    --local iShowTime = iViewTime + 60*1
    self:SetData("show_time", iShowTime)

    local iPriceTime = 6
    if type(mInfo.auction_time) == "number" then
        iPriceTime = mInfo.auction_time
    else
        iPriceTime = formula_string(mInfo.auction_time, {price=self:GetPrice()})
    end
    --iPriceTime = 3
    --self:SetData("price_time", math.floor(iShowTime + iPriceTime*60))
    self:SetData("price_time", math.floor(iShowTime + iPriceTime*3600))
    self:Dirty()
end

function CProxy:GetViewTime()
    return self:GetData("view_time")
end

function CProxy:GetShowTime()
    return self:GetData("show_time")
end

function CProxy:GetPriceTime()
    return self:GetData("price_time")
end

function CProxy:InViewTime()
    return get_time() < self:GetViewTime()
end

function CProxy:InShowTime()
    local iTime = get_time()
    return iTime >= self:GetViewTime() and iTime < self:GetShowTime()
end

function CProxy:InPriceTime()
    local iTime = get_time()
    return iTime >= self:GetShowTime() and iTime < self:GetPriceTime()
end

function CProxy:CheckStatus()
    if self:InViewTime() or self:InShowTime() then
        self:CancelAuction()
        return
    end

    --公示期结束
    if math.abs(get_time() - self:GetShowTime()) <= 10 then
        local mReplace = {item = self.m_oDataCtrl:Name()}
        self:MailNotifyFollows(1007, mReplace)
        local iAnnounce = self:GetTableKey("announce")
        if iAnnounce and iAnnounce > 0 then
            global.oToolMgr:SysAnnounce(iAnnounce, mReplace)
        end
    end

    if self:InPriceTime() then
        self:TryGenProxyBidders()
        return
    end

    self:AuctionOver()
    global.oAuction:CheckAuction()
end

function CProxy:CancelAuction(bForce)
    if self:GetTableKey("is_open") == 1 and not bForce then
        return
    end

    local iProxy = self:GetID()
    local lPlayer = table_key_list(self.m_mProxyBidders)
    if #lPlayer <= 0 then
        record.log_db("huodong", "auction", {info = {
            action = "取消拍卖",
            item = self:LogName(),
        }})

        global.oAuction:RemoveProxy(iProxy)
        return
    end

    global.oToolMgr:ExecuteList(lPlayer, 100, 500, 0, "CancelAuction", function(iPid)
        local oProxy = global.oAuction:GetProxyById(iProxy)
        if oProxy then
            oProxy:RemoveProxyBidder(iPid, 2010, "取消拍卖"..oProxy:LogName())
            local lPlayer = table_key_list(oProxy.m_mProxyBidders)
            if #lPlayer <= 0 then
                oProxy:CancelAuction(bForce)
            end
        end
    end)
end

function CProxy:GetStatus(iPid)
    local iTime = get_time()
    if iTime < self:GetShowTime() then
        return defines.PROXY_STATUS_SHOW
    elseif iTime < self:GetPriceTime() then
        return defines.PROXY_STATUS_PRICE
    else
        return defines.PROXY_STATUS_EMPTY
    end
end

function CProxy:SetAmount(iAmount)
    self:SetData("amount", iAmount)
    self:Dirty()
end

function CProxy:AddAmount(iAdd)
    local iAmount = self:GetAmount()
    self:SetAmount(math.max(0, iAmount+iAdd))
end

function CProxy:GetAmount()
    return self:GetData("amount", 0)
end

function CProxy:SetMoneyType(iType)
    self:SetData("money_type", iType)
    self:Dirty()
end

function CProxy:GetMoneyType()
    return self:GetData("money_type") or self:GetTableKey("money_type")
end

function CProxy:SetPrice(iPrice)
    self:SetData("price", iPrice)
    self:Dirty()
end

function CProxy:GetPrice()
    return self:GetData("price")
end

function CProxy:SetBidder(iPid)
    self:SetData("bidder", iPid)
    self:Dirty()
end

function CProxy:GetBidder()
    return self:GetData("bidder")
end

function CProxy:SetBidderPrice(iPrice)
    self:SetData("bidder_price", iPrice)
    self:Dirty()

    local iPriceTime = self:GetPriceTime()
    if iPrice and iPriceTime - get_time() < 10*60 then
        self:SetData("price_time", get_time() + 10*60)

        local mNet = {
            id = self.m_ID,
            price = iPrice or (self:GetBidderPrice() or self:GetPrice()),
            price_time = self:GetData("price_time"),
            bidder = self:GetBidder(),
        }
        global.oAuction.m_oOperator:BroadCast("GS2CAuctionPriceChange", mNet)
    end
end

function CProxy:GetBidderPrice()
    return self:GetData("bidder_price")
end

function CProxy:SetProxyBidder(iPid)
    self:SetData("proxy_bidder", iPid)
    self:Dirty()
end

function CProxy:GetProxyBidder()
    return self:GetData("proxy_bidder")
end

function CProxy:SetProxyBidderPrice(iPrice)
    self:SetData("proxy_bidder_price", iPrice)
    self:Dirty()
end

function CProxy:AddProxyBidderPrice(iPrice)
    local iProxyPrice = self:GetData("proxy_bidder_price")
    if iProxyPrice then
        iPrice = iProxyPrice + iPrice
    end
    self:SetProxyBidderPrice(iPrice)
end

function CProxy:GetProxyBidderPrice()
    return self:GetData("proxy_bidder_price")
end

function CProxy:GetName()
    return self.m_oDataCtrl:Name()
end

function CProxy:Quality()
    if self:Type() == defines.PROXY_TYPE_ITEM then
        return self.m_oDataCtrl:Quality()
    end
end

function CProxy:LogName()
    return string.format("%s[%s]", self:GetName(), self:GetSys())
end

function CProxy:GetFollows()
    return self.m_mFollows
end

function CProxy:AddFollowPid(iPid)
    self.m_mFollows[iPid] = 1
    self:Dirty()
end

function CProxy:RemoveFollowPid(iPid)
    self.m_mFollows[iPid] = nil
    self:Dirty()
end

function CProxy:FollowSize()
    return table_count(self.m_mFollows)
end

function CProxy:IsFollow(iPid)
    return self.m_mFollows[iPid]
end

function CProxy:RemoveFollows()
    local oAuction = global.oAuction
    for iPid, _ in pairs(self.m_mFollows) do
        self:RemoveFollowPid(iPid)
    end
    self.m_mFollows = {}
    self:Dirty()
end

function CProxy:AddProxyBidder(iPid, iPrice)
    if not self.m_mProxyBidders[iPid] then
        self.m_mProxyBidders[iPid] = 0
    end
    self.m_mProxyBidders[iPid] = self.m_mProxyBidders[iPid] + iPrice
    self:Dirty()
end

function CProxy:RemoveProxyBidder(iPid, iMail, sReason)
    if not self.m_mProxyBidders[iPid] then return end

    local iPrice = self.m_mProxyBidders[iPid]
    local iMoneyType = self:GetMoneyType()
    sReason = sReason..self:LogName()
    self.m_mProxyBidders[iPid] = nil
    self:Dirty()

    local oOperator = global.oAuction.m_oOperator
    oOperator:ReturnMoney2Pid(self, iPid, iPrice, iMail, sReason)
end

function CProxy:GetProxyBidders()
    return self.m_mProxyBidders
end

function CProxy:IsProxyBidder(iPid)
    return self.m_mProxyBidders[iPid] and true or false
end

function CProxy:GetProxyPrice(iPid)
    return self.m_mProxyBidders[iPid] or 0
end

function CProxy:HasProxyPrice(iPrice)
    for iPid, iSetPrice in pairs(self.m_mProxyBidders) do
        if iPrice == iSetPrice then
            return true
        end
    end
    return false
end

function CProxy:TryGenProxyBidders()
    if self:GetData("gen_proxy_price", 0) == 1 then
        return
    end
    self:SetData("gen_proxy_price", 1)
    self:Dirty()

    local iLen = table_count(self.m_mProxyBidders)
    if iLen <= 0 then return end
    if iLen == 1 then
        for iPid, iValue in pairs(self.m_mProxyBidders) do
            self:SetProxyBidder(iPid)
            self:SetProxyBidderPrice(iValue)
            self.m_mProxyBidders[iPid] = nil
        end
        global.oAuction.m_oOperator:CheckProxyPrice(self)
    else
        local lPidList = table_key_list(self.m_mProxyBidders)
        table.sort(lPidList, function (x, y)
            local iPriceX = self.m_mProxyBidders[x]
            local iPriceY = self.m_mProxyBidders[y]
            if iPriceX == iPriceY then
                return x < y
            else
                return iPriceX > iPriceY
            end
        end)
        local iFirst, iSecond = lPidList[1], lPidList[2]
        self:SetBidder(iSecond)
        self:SetBidderPrice(self.m_mProxyBidders[iSecond])
        self:SetProxyBidder(iFirst)
        self:SetProxyBidderPrice(self.m_mProxyBidders[iFirst])
        global.oAuction.m_oOperator:CheckProxyPrice(self)
        self:PriceChangeNotifyFollow()

        self.m_mProxyBidders[iFirst] = nil
        self.m_mProxyBidders[iSecond] = nil

        local iProxy = self:GetID()
        global.oToolMgr:ExecuteList(lPidList, 100, 500, 0, "CancelAuction1", function(iPid)
            local oProxy = global.oAuction:GetProxyById(iProxy)
            if oProxy then
                oProxy:RemoveProxyBidder(iPid, 1005, "初始化代理")
            end
        end)
    end
end

function CProxy:GetCatalog()
    local mInfo = self:GetTableData()
    return mInfo["cat_id"], mInfo["sub_id"]
end

function CProxy:GetMinBidPrice()
    local iBidPrice = self:GetBidderPrice() or self:GetPrice()
    return math.floor(iBidPrice + self:GetPrice() // 10)
end

function CProxy:GetMinProxyPrice()
    local iBidPrice = self:GetBidderPrice() or self:GetPrice()
    return math.floor(iBidPrice + self:GetPrice() // 10)
end

function CProxy:ReturnMoney2ProxyBidder()
    local oAuction = global.oAuction
    local iBidder = self:GetProxyBidder()
    if not iBidder then return end
   
    local iPrice = self:GetProxyBidderPrice()
    if iPrice and iPrice > 0 then 
        global.oWorldMgr:LoadProfile(iBidder, function(obj)
            if not obj then return end
            obj:AddRplGoldCoin(iPrice, "proxy_return")
        end)
    end
end

function CProxy:NewHour()
end

function CProxy:MailNotifyFollows(iMail, mReplace)
    local lPlayer = table_key_list(self.m_mFollows)
    local mMail, sName = global.oMailMgr:GetMailInfo(iMail)
    if mReplace then
        mMail.context = global.oToolMgr:FormatColorString(mMail.context, mReplace)
    end
    local sKey = "MailNotifyFollows"..iMail
    global.oToolMgr:ExecuteList(lPlayer, 100, 500, 0, sKey, function(iPid)
        global.oMailMgr:SendMail(0, sName, iPid, mMail, 0)
    end)
end

function CProxy:PriceChangeNotifyFollow(iPrice)
    interactive.Send(".broadcast", "channel", "SendChannel2Targets", {
        message = "GS2CAuctionPriceChange",
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        id = 1,
        data = {
            id = self.m_ID,
            price = iPrice or (self:GetBidderPrice() or self:GetPrice()),
            price_time = self:GetData("price_time"),
            bidder = self:GetBidder(),
        },
        targets = self.m_mFollows,
    })

    local mData = {
        id = self.m_ID,
        price = iPrice or (self:GetBidderPrice() or self:GetPrice()),
        price_time = self:GetData("price_time"),
        bidder = self:GetBidder(),
    }
    global.oAuction.m_oOperator:BroadCast("GS2CAuctionPriceChange", mData)
end

function CProxy:AuctionOver()
    if self:GetData("auction_over", 0) == 1 then
        return
    end

    self:SetData("auction_over", 1)
    self:PriceChangeNotifyFollow(0)
    global.oAuction.m_oOperator:RewardAuction(self)
    global.oAuction:RemoveProxy(self:GetID())

    record.log_db("huodong", "auction", {info = {
        action = "拍卖结束",
        item = self:LogName(),
    }})
end

function CProxy:PackSimpleInfo(iPid)
    local mData = {}
    mData.id = self:GetID()
    mData.type = self:Type()
    mData.sid = self:SID()
    mData.price = self:GetBidderPrice() or self:GetPrice()
    mData.money_type = self:GetMoneyType()
    --mData.view_time = self:GetViewTime()
    mData.view_time = 0
    mData.show_time = self:GetShowTime()
    mData.price_time = self:GetPriceTime()
    mData.is_follow = self:IsFollow(iPid) and 1 or 0
    mData.proxy_bidder = self:GetProxyBidder()
    mData.proxy_price = self:GetProxyPrice(iPid)
    mData.bidder = self:GetBidder()
    mData.sys_idx = self:GetSys()
    mData.quality = self:Quality()
    mData.base_price = self:GetPrice()
    return mData
end

function CProxy:GetTableData()
    local mInfo = res["daobiao"]["auction"]["sys_auction"]
    return mInfo[self:GetData("sys")] or {}
end

function CProxy:GetTableKey(sKey)
    local mInfo = self:GetTableData()
    return mInfo[sKey]
end
