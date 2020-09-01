local global = require "global"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))

--编号-{名字 路径}
-- [201],[202] 商店 id 被运营活动欢乐返利使用
SHOPLIST = {
    [101] = {"wuxun","wuxun"},
    [102] = {"jjcpoint","jjcpoint"},
    [103] = {"leaderpoint", "leaderpoint"},
    [104] = {"xiayipoint", "xiayipoint"},
    [105] = {"summonpoint", "summonpoint"},
    [106] = {"chumopoint", "chumopoint"},
    [201] = {"joyexpenseold","joyexpenseold"},
    [202] = {"joyexpensenew","joyexpensenew"},
}

function NewShopMgr(...)
    return CShopMgr:New(...)
end

CShopMgr = {}
CShopMgr.__index = CShopMgr
inherit(CShopMgr, logic_base_cls())

function CShopMgr:New()
    local o = super(CShopMgr).New(self)
    o.m_mShop = {}
    for iShop, mInfo in pairs(SHOPLIST) do
        local sShopName , sDir = mInfo[1],mInfo[2]
        local sPath = string.format("shop.%s",sShopName)
        local oModule = import(service_path(sPath))
        assert(oModule,string.format("Create shop err:%s %s",sShopName,sPath))
        local oShop = oModule.NewShop(iShop,sShopName)
        o.m_mShop[iShop] = oShop
        oShop:Init()
    end
    return o
end

function CShopMgr:GetShop(iShop)
    return self.m_mShop[iShop]
end

function CShopMgr:ValidOpen(iShop)
    
end

function CShopMgr:OpenShop(oPlayer,iShop)
    local oShop = self:GetShop(iShop)
    if oShop then
        oShop:OpenShop(oPlayer)
    end
end

function CShopMgr:DailyRewardMoneyInfo(oPlayer,iShop)
    local oShop = self:GetShop(iShop)
    if oShop then
        oShop:DailyRewardMoneyInfo(oPlayer)
    end
end

function CShopMgr:BuyGood(oPlayer,iShop,iGood,iAmount,iMoneyType)
    local oShop = self:GetShop(iShop)
    if oShop then
        oShop:DoBuy(oPlayer,iGood,iAmount,iMoneyType)
    end
end

function CShopMgr:TestOP(oPlayer,iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer:GetPid()
    mArgs = mArgs or {}
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：teamop 参数 {参数,参数,...}")
        return
    end
    local mCommand={
        "100 指令查看",
        "101 清除天限制\nshopop 101",
        "102 清除周限制\nshopop 102",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        local lDel = {}
        for sKey,mData in pairs(oPlayer.m_oTodayMorning.m_mKeepList) do
            if string.find(sKey,"shopday") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oTodayMorning:Delete(sKey)
        end
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 102 then
        local lDel = {}
        for sKey,mData in pairs(oPlayer.m_oTodayMorning.m_mKeepList) do
            if string.find(sKey,"shopweek") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oTodayMorning:Delete(sKey)
        end
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 301 then
        local iShop = mArgs.shop or 101
        local iGood = mArgs.good  or 1002
        local iAmount = mArgs.amount or 1
        local iMoneyType = 6
        self:BuyGood(oPlayer,iShop,iGood,iAmount,iMoneyType)
    elseif iFlag == 302 then
        local iShop = mArgs.shop 
        self:OpenShop(oPlayer,iShop)
    end
end
