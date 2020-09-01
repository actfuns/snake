--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local loadbuild = import(service_path("org.loadobj"))


function NewBuildMgr(...)
    return COrgBuildMgr:New(...)
end

COrgBuildMgr = {}
COrgBuildMgr.__index = COrgBuildMgr
inherit(COrgBuildMgr, datactrl.CDataCtrl)

function COrgBuildMgr:New(orgid)
    local o = super(COrgBuildMgr).New(self, {orgid = orgid})
    o:Init()
    return o
end

function COrgBuildMgr:Init()
    self.m_mBuilding = {}

    local lBuildId = {101, 104}
    for _,iBid in pairs(lBuildId) do
        local oBuild = loadbuild.NewBuild(iBid, self:GetInfo("orgid"))
        oBuild:AddLevel(1)
        self.m_mBuilding[iBid] = oBuild
    end
end

function COrgBuildMgr:Release()
    for _, oBuild in pairs(self.m_mBuilding) do
        baseobj_safe_release(oBuild)
    end
    self.m_mBuilding = {}
    super(COrgBuildMgr).Release(self)
end

function COrgBuildMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgBuildMgr:GetBuildById(iBid)
    return self.m_mBuilding[iBid]
end

function COrgBuildMgr:GetBuildHome()
    return self:GetBuildById(101)
end

function COrgBuildMgr:GetBuildShop()
    return self:GetBuildById(102)
end

function COrgBuildMgr:GetBuildHouse()
    return self:GetBuildById(103)
end

function COrgBuildMgr:GetBuildFane()
    return self:GetBuildById(104)
end

function COrgBuildMgr:GetBuildCash()
    return self:GetBuildById(105)
end

function COrgBuildMgr:GetBuildHomeLevel()
    local oBuild = self:GetBuildHome()
    if not oBuild then return 0 end

    return oBuild:Level() 
end

function COrgBuildMgr:GetBuildCashLevel()
    local oBuild = self:GetBuildCash()
    if not oBuild then return 0 end

    return oBuild:Level()
end

function COrgBuildMgr:GetBuildHouseLevel()
    local oBuild = self:GetBuildHouse()
    if not oBuild then return 0 end

    return oBuild:Level()
end

function COrgBuildMgr:GetBuildLevelByBid(iBid)
    local oBuild = self:GetBuildById(iBid)
    if oBuild then
        return oBuild:Level()
    end
    return 0
end

function COrgBuildMgr:GetMinBuildLevel()
    local lLevel = {}
    for _, oBuild in pairs(self.m_mBuilding) do
        table.insert(lLevel, oBuild:Level())
    end

    if #lLevel < 5 then return 0 end
        
    return math.min(table.unpack(lLevel))
end

function COrgBuildMgr:GetXueTuCnt()
    local oBuild = self:GetBuildHouse()
    if not oBuild or oBuild:Level() <= 0 then return 0 end

    return oBuild:GetAddMaxXueTu()
end

function COrgBuildMgr:GetMemberCnt()
    local oBuild = self:GetBuildHouse()
    if not oBuild or oBuild:Level() <= 0 then return 0 end

    return oBuild:GetAddMaxMem()
end

function COrgBuildMgr:GetMaxCash()
    local oBuild = self:GetBuildCash()
    if not oBuild or oBuild:Level() <= 0 then return 0 end

    return oBuild:GetAddMaxCash()
end

function COrgBuildMgr:Release()
    for _, oBuild in pairs(self.m_mBuilding) do
        baseobj_safe_release(oBuild)
    end
    super(COrgBuildMgr).Release(self)
end

function COrgBuildMgr:Load(mData)
    if not mData then return end
    for sBid, m in pairs(mData) do
        local oBuild = self.m_mBuilding[tonumber(sBid)]
        if not oBuild then
            oBuild = loadbuild.NewBuild(tonumber(sBid), self:GetInfo("orgid"))
        end
        oBuild:Load(m)
        self.m_mBuilding[tonumber(sBid)] = oBuild
    end
end

function COrgBuildMgr:AfterLoad()
    for _,oBuild in pairs(self.m_mBuilding) do
        oBuild:AfterLoad()
    end
end

function COrgBuildMgr:Save()
    local mData = {}
    for iBid, oBuild in pairs(self.m_mBuilding) do
        mData[db_key(iBid)] = oBuild:Save()
    end    
    return mData
end

function COrgBuildMgr:IsDirty()
    local bDirty = super(COrgBuildMgr).IsDirty(self)
    if bDirty then return true end

    for _, oBuild in pairs(self.m_mBuilding) do
        if oBuild:IsDirty() then return true end
    end
    return false
end

function COrgBuildMgr:UnDirty()
    super(COrgBuildMgr).UnDirty(self)
    for _, oBuild in pairs(self.m_mBuilding) do
        oBuild:UnDirty()
    end
end

function COrgBuildMgr:GetHasBuilding()
    for _,oBuild in pairs(self.m_mBuilding) do
        if oBuild:IsUpGrade() then
            return oBuild
        end
    end
    return nil
end

function COrgBuildMgr:UpGradeBuild(oPlayer, iBid)
    local oBuild = self:GetBuildById(iBid)
    if not oBuild then
        oBuild = loadbuild.NewBuild(iBid, self:GetInfo("orgid"))
        self.m_mBuilding[iBid] = oBuild
    end

    oBuild:UpGradeBuild()
    oPlayer:Send("GS2CGetBuildInfo", {infos={oBuild:PackBuildInfo(oPlayer:GetPid())}})
    self:Dirty()
end

function COrgBuildMgr:NewHour(mNow)
    for _, oBuild in pairs(self.m_mBuilding) do
        oBuild:NewHour(mNow)
    end
end

function COrgBuildMgr:GS2CGetBuildInfo(oPlayer)
    local mNet = {}
    for _, oBuild in pairs(self.m_mBuilding) do
        table.insert(mNet, oBuild:PackBuildInfo(oPlayer:GetPid()))
    end
    oPlayer:Send("GS2CGetBuildInfo", {infos=mNet})
end

function COrgBuildMgr:GetBuildLevelData(iBid, iLv) 
    local mData = res["daobiao"]["org"]["buildlevel"]
    if mData[iBid] then
        return mData[iBid][iLv]
    end
    return nil
end

function COrgBuildMgr:QuickBuild(oPlayer, iBid, iQuick)
    local oBuild = self:GetBuildById(iBid)
    if not oBuild then return end
    if oBuild:GetQuickNum(oPlayer:GetPid()) >= 3 then return end
    
    local oOrgMgr = global.oOrgMgr
    if not oBuild:IsUpGrade() then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1082))
        return
    end

    local mData = res["daobiao"]["org"]["quick"][iQuick]
    if not mData then return end

    local sMoneyType, iQuickSec = mData["cost"]["type"], mData["quick_time"]
    local iMoney, iOffer = mData["cost"]["val"], mData["reward_offer"]
    local iLeftTime = oBuild:GetLeftTime()
    if iLeftTime < iQuickSec then
        iMoney = math.ceil(iMoney * iLeftTime / iQuickSec)
        iOffer = math.ceil(iOffer * iLeftTime / iQuickSec)
    end

    if not oPlayer:ValidMoneyByType(sMoneyType, iMoney) then return end

    local oOrg = self:GetOrg()
    local mLog = oOrg:LogData()
    mLog["old_offer"] = oPlayer:GetOffer()
    mLog["pid"] = oPlayer:GetPid()
    mLog["buildid"] = iBid

    oPlayer:ResumeMoneyByType(sMoneyType, iMoney, "帮派快速建造")
    oPlayer:AddOrgOffer(iOffer, "buildshop quick_build")

    mLog["now_offer"] = oPlayer:GetOffer()    
    mLog["left_time"] = iLeftTime
    mLog["quick_sec"] = iQuickSec
    mLog["money_type"] = sMoneyType
    mLog["money_val"] = iMoney
    record.log_db("org", "quick_build", mLog)

    oBuild:QuickBuild(oPlayer:GetPid(), iQuickSec)
    oPlayer:Send("GS2CGetBuildInfo", {infos={oBuild:PackBuildInfo(oPlayer:GetPid())}})
    if iBid == self:GetBuildHome():BuildID() then
        oOrg:GS2COrgInfoChange(oPlayer:GetPid(), {level=self:GetBuildHomeLevel()})    
    end
end

function COrgBuildMgr:GS2CGetShopInfo(oPlayer)
    local oShop = self:GetBuildShop()
    local oOrg = self:GetOrg()
    if not oShop or oShop:Level() <= 0 then return end

    if oShop:IsNeedRefresh(oPlayer:GetPid()) then
        oShop:RefreshShop(oPlayer:GetPid())
        oPlayer:Send("GS2COrgFlag", oOrg:PackOrgFlag({shop_status=0}))
    end

    oPlayer:Send("GS2CGetShopInfo", {items=oShop:PackShopInfo(oPlayer:GetPid())})
end

function COrgBuildMgr:BuyItem(oPlayer, iItem, iCnt)
    local oShop = self:GetBuildShop()
    local oOrg = self:GetOrg()
    local oOrgMgr = global.oOrgMgr
    if not oShop or not oOrg then return end

    if oOrg:IsXueTu(oPlayer:GetPid()) then
        local sMsg = oOrgMgr:GetOrgText(1148)
        oPlayer:NotifyMessage(sMsg)
        return
    end

    if oShop:IsNeedRefresh(oPlayer:GetPid()) then
        oShop:RefreshShop(oPlayer:GetPid())
        oPlayer:Send("GS2COrgFlag", oOrg:PackOrgFlag({shop_status=0}))
        oPlayer:Send("GS2CGetShopInfo", {items=oShop:PackShopInfo(oPlayer:GetPid())})
        local sMsg = oOrgMgr:GetOrgText(1109)
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local bBuy = oShop:Buy(oPlayer, iItem, iCnt)
    if bBuy then
        oPlayer:Send("GS2CBuyItemResult", {})
    end
end

function COrgBuildMgr:GetShopStatus(iPid)
    local oShop = self:GetBuildShop()
    if not oShop then return end

    if oShop:IsNeedRefresh(iPid) then return 1 end

    return 0
end


