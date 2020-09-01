local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "优惠甩卖"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    self:CheckHuodong(oPlayer)
end

function CHuodong:CheckHuodong(oPlayer)
    local sKey = self:GetDiscountSaleTimeKey()
    local iTime = oPlayer:Query(sKey, 0)
    if iTime > 0 then
        local mGoods = self:GetGoodsConfigInfo()
        local iCnt = table_count(mGoods)
        local iNowTime = get_time()
        if iNowTime - iTime < iCnt * 24 * 3600 then
            -- 活动时间内
            self:GS2CDiscountSale(oPlayer)
        end 
    else
        if global.oToolMgr:IsSysOpen("DISCOUNT_SALE", oPlayer, true) then
            self:OpenDiscountSale(oPlayer)
        else
            self:AddUpgradeEvent(oPlayer)
        end
    end
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
    local sKey = self:GetDiscountSaleTimeKey()
    local iTime = oPlayer:Query(sKey, 0)
    if iTime > 0 then return end

    if global.oToolMgr:IsSysOpen("DISCOUNT_SALE", oPlayer, true) then
        self:OpenDiscountSale(oPlayer)
    end
end

function CHuodong:OpenDiscountSale(oPlayer)
    if not oPlayer then return end

    self:DelUpgradeEvent(oPlayer)
    oPlayer:Set(self:GetDiscountSaleTimeKey(), get_time())
    self:GS2CDiscountSale(oPlayer)
end

function CHuodong:GetDiscountSaleTimeKey()
    return "discount_sale_time"
end

function CHuodong:GenGoodsKey(iDay)
    return string.format("discount_sale_%s", iDay)
end

function CHuodong:GS2CDiscountSale(oPlayer)
    local iTime = oPlayer:Query(self:GetDiscountSaleTimeKey())
    local mNet = {}
    mNet.start_time = iTime
    mNet.buy_info = {}
    for iDay, mConfig in pairs(self:GetGoodsConfigInfo()) do
        local sKey = self:GenGoodsKey(iDay)
        table.insert(mNet.buy_info, {day=iDay, status=oPlayer:Query(sKey, 0)})
    end

    oPlayer:Send("GS2CDiscountSale", mNet)
end

function CHuodong:TryBuy(oPlayer, iDay)
    local mData = self:GetGoodsConfigInfo()
    local mConfig = mData[iDay]
    if not mConfig then
        record.warning(string.format("CHuodong:TryBuy discount_sale not config %s", iDay))
        return
    end
    
    local sKey = self:GenGoodsKey(iDay)
    if oPlayer:Query(sKey, 0) > 0 then
        oPlayer:NotifyMessage(self:GetTextData(1003))
        return
    end

    local iTime = oPlayer:Query(self:GetDiscountSaleTimeKey(), 0)
    local iNowTime = get_time()
    local iCurDay = math.ceil((iNowTime - iTime) / (24*3600)) 
    if iDay > iCurDay then
        oPlayer:NotifyMessage(self:GetTextData(1004))
        return
    elseif iDay < iCurDay then
        oPlayer:NotifyMessage(self:GetTextData(1001))
        return
    end

    local mGiveItem = {}
    for _,mGoods in pairs(mConfig.goods_rewards) do
        mGiveItem[mGoods.sid] = mGoods.num
    end
    local iGoldCoin = mConfig.discount_price
    if not oPlayer:ValidGoldCoin(iGoldCoin) then return end

    oPlayer:Set(sKey, 1)
    oPlayer:ResumeGoldCoin(iGoldCoin, self.m_sTempName)
    local iPid = oPlayer:GetPid()
    if oPlayer.m_oItemCtrl:ValidGive(mGiveItem) then
        for iSid, iNum in pairs(mGiveItem) do
            oPlayer:RewardItems(iSid, iNum, self.m_sTempName, {bind=true})
        end
    else
        local oMailMgr = global.oMailMgr
        local mMail, sName = oMailMgr:GetMailInfo(1001)
        local lMailItem = {} 
        for iSid, iNum in pairs(mGiveItem) do
            local oItem = global.oItemLoader:Create(iSid)
            if iSid < 10000 then
                oItem:SetData("Value", iNum)
            else
                oItem:Bind(iPid)
                oItem:SetAmount(iNum)
            end
            table.insert(lMailItem, oItem)
        end
        oMailMgr:SendMail(0, sName, iPid, mMail, 0, lMailItem)
    end
    self:GS2CDiscountSale(oPlayer)

    record.log_db("huodong", "discount_sale_buy", {
        pid = iPid,
        day = iDay,
        start_time = iTime,
        items = mGiveItem,
        goldcoin = iGoldCoin,  
    })
end

function CHuodong:GetGoodsConfigInfo()
    return res["daobiao"]["huodong"][self.m_sName]["discount_goods"]
end

function CHuodong:GetTextData(iText, mReplace)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetSystemText({"huodong", self.m_sName}, iText, mReplace)
end

