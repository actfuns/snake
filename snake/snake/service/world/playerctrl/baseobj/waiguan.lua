local global = require "global"
local extend = require "base/extend"
local res = require "base.res"
local record = require "public.record"
local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

local SZ_FOREVER = 1
local SZ_DEFAULT = 0
local TYPE_FOREVER = 1
local TYPE_SEVEN = 2

local CLOTHES_PART = {}
CLOTHES_PART.HAIR = 1
CLOTHES_PART.CLOTHES = 2
CLOTHES_PART.PANT = 3

function NewWaiGuan(...)
    return CWaiGuan:New(...)
end

CWaiGuan = {}
CWaiGuan.__index = CWaiGuan
inherit(CWaiGuan, datactrl.CDataCtrl)

function CWaiGuan:New(pid)
    local o = super(CWaiGuan).New(self, {pid = pid})
    o.m_iCurClothes = 0
    o.m_iCurHair = 0
    o.m_iCurSZ = 0
    o.m_iCurPant = 0
    o.m_mShiZhuang = {}
    return o
end

function CWaiGuan:Release()
    for _,szobj in pairs(self.m_mShiZhuang) do
        szobj:Release()
    end
    super(CWaiGuan).Release(self)      
end

function CWaiGuan:NewHour(mNow)
    for _,szobj in pairs(self.m_mShiZhuang) do
        szobj:SetValidTimer()
    end
end

function CWaiGuan:IsDirty()
    if super(CWaiGuan).IsDirty(self) then
        return true
    end
    for _,szobj in pairs(self.m_mShiZhuang) do
        if szobj:IsDirty() then
            return true
        end
    end
    return false
end

function CWaiGuan:UnDirty()
    super(CWaiGuan).UnDirty(self)
    for _,szobj in pairs(self.m_mShiZhuang) do
        szobj:UnDirty()
    end
end

function CWaiGuan:Save()
    local mData = {}
    mData["curclothes"] = self.m_iCurClothes
    mData["curhair"] = self.m_iCurHair
    mData["curpant"] = self.m_iCurPant
    mData["cursz"] = self.m_iCurSZ
    local mShiZhuang = {}
    for iSZ,szobj in pairs(self.m_mShiZhuang) do
        mShiZhuang[db_key(iSZ)] = szobj:Save()
    end
    mData["shizhuang"] = mShiZhuang
    return mData
end

function CWaiGuan:Load(mData)
    mData = mData or {}
    self.m_iCurClothes = mData["curclothes"] or 0
    self.m_iCurHair = mData["curhair"] or 0
    self.m_iCurPant = mData["curpant"] or 0
    self.m_iCurSZ = mData["cursz"] or SZ_DEFAULT
    local mShiZhuang = mData["shizhuang"] or {}
    for sSZ,mSZData in pairs(mShiZhuang) do
        local iSZ = tonumber(sSZ)
        if res["daobiao"]["ranse"]["shizhuang"][iSZ] then
            local szobj = NewShiZhuang(iSZ)
            szobj:Load(mSZData)
            szobj:SetInfo("pid",self:GetInfo("pid",0))
            self.m_mShiZhuang[iSZ] = szobj
        else
            self:Dirty()
            record.warning(string.format("load shizhuang %s %s",self:GetInfo("pid",0),iSZ))
        end
    end
    local oCurSZ = self.m_mShiZhuang[self.m_iCurSZ]
    if oCurSZ and not oCurSZ:IsValidUse() then
        self.m_iCurSZ = SZ_DEFAULT
    end
end

function CWaiGuan:GetResumeReason(iPart, iFlag)
    if iFlag then
        iFlag = 1
    else
        iFlag = 0
    end
    local iText = iPart * 1000 + iFlag
    return res["daobiao"]["ranse"]["resume_reason"][iText]["text"]
end

-- 染色部位 头发 1 衣服 2 裤子 3
function CWaiGuan:GetClothesPartCurColor(iPart)
    if iPart == CLOTHES_PART.HAIR then
        return self:GetCurHair()
    elseif iPart == CLOTHES_PART.CLOTHES then
        return self:GetCurClothes()
    elseif iPart == CLOTHES_PART.PANT then
        return self:GetCurPant()
    else
        return nil
    end
end

-- 染色部位 头发 1 衣服 2 裤子 3
function CWaiGuan:SetClothesPartColor(iPart, iColor)
    if iPart == CLOTHES_PART.HAIR then
        self:SetCurHair(iColor)
    elseif iPart == CLOTHES_PART.CLOTHES then
        self:SetCurClothes(iColor)
    elseif iPart == CLOTHES_PART.PANT then
        self:SetCurPant(iColor)
    end
end

function CWaiGuan:GetCurClothes()
    return self.m_iCurClothes
end

function CWaiGuan:SetCurClothes(iColor)
    self:Dirty()
    self.m_iCurClothes = iColor
end

function CWaiGuan:GetCurHair()
    return self.m_iCurHair
end

function CWaiGuan:SetCurHair(iColor)
    self:Dirty()
    self.m_iCurHair = iColor
end

function CWaiGuan:GetCurPant()
    return self.m_iCurPant
end

function CWaiGuan:SetCurPant(iColor)
    self:Dirty()
    self.m_iCurPant = iColor
end

function CWaiGuan:GetShiZhuang(iSZ)
    return self.m_mShiZhuang[iSZ]
end

function CWaiGuan:SetShiZhuang(szobj)
    self:Dirty()
    self.m_mShiZhuang[szobj:SZID()] = szobj 
    szobj:SetInfo("pid",self:GetInfo("pid",0))
    szobj:SetValidTimer()
end

function CWaiGuan:SetShiZhuangByID(iSZ, mArgs)
    local oShiZhuang = self:GetShiZhuang(iSZ)
    if not oShiZhuang then
        oShiZhuang = NewShiZhuang(iSZ)
    end

    mArgs = mArgs or {}
    if not oShiZhuang:IsForever() and mArgs.opentime then
        oShiZhuang:AddOpenTime(mArgs.opentime)
    end
    self:SetShiZhuang(oShiZhuang)
end

function CWaiGuan:GetCurSZObj()
    return self:GetShiZhuang(self:GetCurSZ())
end

function CWaiGuan:GetCurSZ()
    return self.m_iCurSZ
end

function CWaiGuan:GetCurSZColor()
    local szobj = self.m_mShiZhuang[self.m_iCurSZ]
    if not szobj then
        return 0
    end
    return szobj:GetCurColor()
end

function CWaiGuan:SetCurSZ(iSZ)
    if iSZ == SZ_DEFAULT then
        self:Dirty()
        self.m_iCurSZ = iSZ
    else
        local szobj = self.m_mShiZhuang[iSZ]
        assert(szobj,string.format("SetCurSZ  %s %s",self:GetInfo("pid"),iSZ))
        if not szobj:IsValidUse() then
            assert(szobj,string.format("SetCurSZ  %s %s",self:GetInfo("pid"),iSZ)) 
        end
        self:Dirty()
        self.m_iCurSZ = iSZ
    end
end

function CWaiGuan:GetOwner()
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
end

function CWaiGuan:OnLogin(oPlayer, bReEnter)
    self:GS2CLoginShiZhuang()
end

function CWaiGuan:GS2CLoginShiZhuang()
    local mNet = self:PackAllSZ()
    table.insert(mNet, self:PackBaseColor())
    local oPlayer = self:GetOwner()
    oPlayer:Send("GS2CLoginShiZhuang",{szlist=mNet})
end

function CWaiGuan:PackBaseColor()
    local mNet = {
        sz = 0,
        curclothes = self.m_iCurClothes,
        curhair = self.m_iCurHair,
        curpant = self.m_iCurPant,
    }
    return mNet
end

function CWaiGuan:PackAllSZ()
    local mSZ = {}
    for iSZ,szobj in pairs(self.m_mShiZhuang) do
        table.insert(mSZ,szobj:PackInfo())
    end
    return mSZ
end

function CWaiGuan:GS2CAllShiZhuang()
    local mNet = {}
    local oPlayer = self:GetOwner()
    mNet.szlist = self:PackAllSZ()
    oPlayer:Send("GS2CAllShiZhuang",mNet)
end

function CWaiGuan:GS2CRefreshShiZhuang(iSZ)
    local szobj =self:GetShiZhuang(iSZ)
    local oPlayer = self:GetOwner()
    local mNet  = {}
    mNet.szobj = szobj:PackInfo()
    oPlayer:Send("GS2CRefreshShiZhuang",mNet)
end

function CWaiGuan:CleanAll()
    self:Dirty()
    self.m_iCurClothes = 0
    self.m_iCurHair = 0
    self.m_iCurSZ = 0
    for _,szobj in pairs(self.m_mShiZhuang) do
        szobj:Release()
    end
    self.m_mShiZhuang = {}
end


function NewShiZhuang(...)
    return CShiZhuang:New(...)
end

CShiZhuang = {}
CShiZhuang.__index = CShiZhuang
inherit(CShiZhuang, datactrl.CDataCtrl)

function CShiZhuang:New(szid)
    local o = super(CShiZhuang).New(self, {szid = szid})
    o.m_iCurClothes = 0
    o.m_iCurHair = 0
    o.m_iCurPant = 0
    o.m_iCurColor = 0
    o.m_iForever = 0
    o.m_iOpenTime = 0
    return o
end

function CShiZhuang:SZID()
    return self:GetInfo("szid")
end

function CShiZhuang:ModelID()
    
end

function CShiZhuang:Save()
    local mData = {}
    mData["curclothes"] = self.m_iCurClothes
    mData["curhair"] = self.m_iCurHair
    mData["curpant"] = self.m_iCurPant
    mData["forever"] = self.m_iForever
    mData["opentime"] = self.m_iOpenTime
    return mData
end

function CShiZhuang:Load(mData)
    mData = mData or {}
    self.m_iCurClothes = mData["curclothes"] or 0
    self.m_iCurHair = mData["curhair"] or 0
    self.m_iCurPant = mData["curpant"] or 0
    self.m_iForever = mData["forever"] or 0
    self.m_iOpenTime = mData["opentime"] or 0
    self:SetValidTimer()
end

-- 染色部位 头发 1 衣服 2 裤子 3
function CShiZhuang:GetClothesPartCurColor(iPart)
    if iPart == CLOTHES_PART.HAIR then
        return self:GetCurHair()
    elseif iPart == CLOTHES_PART.CLOTHES then
        return self:GetCurClothes()
    elseif iPart == CLOTHES_PART.PANT then
        return self:GetCurPant()
    else
        return nil
    end
end

-- 染色部位 头发 1 衣服 2 裤子 3
function CShiZhuang:SetClothesPartColor(iPart, iColor)
    if iPart == CLOTHES_PART.HAIR then
        self:SetCurHair(iColor)
    elseif iPart == CLOTHES_PART.CLOTHES then
        self:SetCurClothes(iColor)
    elseif iPart == CLOTHES_PART.PANT then
        self:SetCurPant(iColor)
    end
end

function CShiZhuang:GetCurClothes()
    return self.m_iCurClothes
end

function CShiZhuang:SetCurClothes(iColor)
    self:Dirty()
    self.m_iCurClothes = iColor
end

function CShiZhuang:GetCurHair()
    return self.m_iCurHair
end

function CShiZhuang:SetCurHair(iColor)
    self:Dirty()
    self.m_iCurHair = iColor
end

function CShiZhuang:GetCurPant()
    return self.m_iCurPant
end

function CShiZhuang:SetCurPant(iColor)
    self:Dirty()
    self.m_iCurPant = iColor
end

function CShiZhuang:SetValidTimer()
    if self.m_iForever == SZ_FOREVER then
        return
    end
    if not self:IsValidUse() then
        return
    end
    local iLeftTime = self.m_iOpenTime - get_time()
    if iLeftTime > 60*60 then
        return
    end
    self:DelTimeCb("SetValidTimer")
    local pid  = self:GetInfo("pid",0)
    local iSZ = self:SZID()
    self:AddTimeCb("SetValidTimer",(iLeftTime+1)*1000,function ()
        _SetValidTimer(pid,iSZ)
    end)
end

function CShiZhuang:CheckOutTime()
    self:DelTimeCb("SetValidTimer")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid",0))
    if not oPlayer then
        return
    end
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    if not self:IsValidUse()  and oWaiGuan.m_iCurSZ == self:SZID() then
        oWaiGuan:SetCurSZ(SZ_DEFAULT)
        oPlayer:SyncModelInfo()
    end
end

function CShiZhuang:GetCurColor()
    return self.m_iCurColor
end

function CShiZhuang:SetCurColor(iColor)
    self:Dirty()
    self.m_iCurColor = iColor
end

function CShiZhuang:GetColor()
    return self.m_mColor
end

function CShiZhuang:AddColor(iColor)
    self:Dirty()
    table.insert(self.m_mColor,iColor)
end

function CShiZhuang:HasColor(iColor)
    return extend.Array.find(self.m_mColor,iColor)
end

function CShiZhuang:IsForever()
    return self.m_iForever == SZ_FOREVER
end

function CShiZhuang:SetForever()
    self:Dirty()
    self.m_iForever = SZ_FOREVER
end

function CShiZhuang:IsValidUse()
    if self.m_iForever == SZ_FOREVER then
        return true
    end
    if self.m_iOpenTime>0  and get_time()<self.m_iOpenTime then
        return true
    end
    return false
end

function CShiZhuang:UpdateOpenTime()
    self:Dirty()
    local iTime = res["daobiao"]["ranse"]["config"][1]["time"]
    assert(iTime>0,string.format("sztime %s",iTime))
    local iTime1 = get_time()+iTime
    local iTime2 = self.m_iOpenTime + iTime
    self.m_iOpenTime = math.max(iTime1,iTime2)
end

function CShiZhuang:AddOpenTime(iTime)
    self:Dirty()
    assert(iTime>0,string.format("sztime %s",iTime))
    local iTime1 = get_time()+iTime
    local iTime2 = self.m_iOpenTime + iTime
    self.m_iOpenTime = math.max(iTime1,iTime2)
end    

function CShiZhuang:PackInfo()
    local mNet = {}
    mNet.sz = self:SZID()
    mNet.curclothes = self.m_iCurClothes
    mNet.curhair = self.m_iCurHair
    mNet.curpant = self.m_iCurPant
    mNet.forever = self.m_iForever
    mNet.time = self.m_iOpenTime
    return mNet
end

function _SetValidTimer(pid,iSZ)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    local oSZ  = oWaiGuan:GetShiZhuang(iSZ)
    if not oSZ then
        return
    end
    oSZ:CheckOutTime()
end

-------接口------------
function CleanAll(oPlayer)
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    oWaiGuan:CleanAll()
end

function GetText(iText)
    return res["daobiao"]["ranse"]["text"][iText]["text"]
end

function ValidColor(colorlist,iColor)
    assert(colorlist,"ValidColor")
    assert(iColor,"ValidColor")
    if iColor == 0 then 
        return true
    end
    for _,mColor in pairs(colorlist) do
        if mColor.color == iColor then
            return true
        end
    end
    return false
end

function GetResume(mRes,iColor)
    local resumelist = mRes.itemlist
    local default_resume =nil 
    if mRes.dresume then
        default_resume = mRes.dresume[1]
    end

    assert(resumelist,"GetResume")
    assert(iColor,"GetResume")
    local mResult = nil
    if iColor>0 then
        for _,mResume in pairs(resumelist) do
            if mResume.color == iColor then
                mResult = {}
                mResult.gold = mResume.gold
                mResult.silver = mResume.silver
                mResult.itemlist = {}
                for itemsid,amount in string.gmatch(mResume.item,"(%d+)*(%d+)") do
                    mResult.itemlist[tonumber(itemsid)]  = tonumber(amount)
                end
                break
            end
        end
    elseif iColor == 0 and default_resume then
        mResult = {}
        mResult.gold = default_resume.gold
        mResult.silver = default_resume.silver
        mResult.itemlist = {}
        for itemsid,amount in string.gmatch(default_resume.item,"(%d+)*(%d+)") do
            mResult.itemlist[tonumber(itemsid)]  = tonumber(amount)
        end
    end
    if not mResult then 
        return false
    end
    return mResult
end

function PlayerRanse(oPlayer,iClothcolor,iHaircolor,iPantcolor,iFlag)
    local oNotifyMgr = global.oNotifyMgr
    local oItemLoader = global.oItemLoader
    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local sSySMsg = GetText(3005)
    local LIMIT_RANSE_GRADE = res["daobiao"]["open"]["RANSE"]["p_level"]
    sSySMsg = string.gsub(sSySMsg,"#level",LIMIT_RANSE_GRADE)
    if not global.oToolMgr:IsSysOpen("RANSE",oPlayer,nil,{plevel_tips = sSySMsg}) then   
        return
    end

    local bSucc = true
    local iGold, iSilver, iGoldCoin, mItem = 0, 0, 0, {}
    if iHaircolor and iHaircolor >= 0 then
        local bResult ,mResult = UnLockClothesPartColor(oPlayer, CLOTHES_PART.HAIR, iHaircolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end

    if iPantcolor and iPantcolor >= 0 then
        local bResult ,mResult = UnLockClothesPartColor(oPlayer, CLOTHES_PART.PANT, iPantcolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end

    if iClothcolor and iClothcolor>=0 then
        local bResult ,mResult = UnLockClothesPartColor(oPlayer, CLOTHES_PART.CLOTHES,iClothcolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end

    if bSucc then
        oNotifyMgr:Notify(oPlayer:GetPid(),"染色成功")
        if iSilver>0 then
            local sMsg = oToolMgr:FormatColorString("你消耗了#silver银币", {silver = iSilver})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        if iGold>0 then
            local sMsg = oToolMgr:FormatColorString("你消耗了#gold金币", {gold = iGold})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        for itemsid,amount in pairs(mItem) do
            local oItem = oItemLoader:GetItem(itemsid)
            local sMsg = oToolMgr:FormatColorString("消耗#amount个#item", {amount = amount, item = oItem:TipsName()})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
        if oWaiGuan and oWaiGuan:GetCurSZ() == 0 then
            oPlayer:SyncModelInfo()
        end
        oPlayer:Send("GS2CRefreshShiZhuang",{szobj=oWaiGuan:PackBaseColor()})
    end
end

-- sPart 是 hair, pant, clothes 中的一种
function UnLockClothesPartColor(oPlayer, iPart, iColor, iFlag)
    local sPart = res["daobiao"]["ranse"]["ranse_part"][iPart]["part"]
    if not sPart then
        return
    end
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local iShape = oPlayer:GetOriginShape()
    local mRes = res["daobiao"]["ranse"][sPart][iShape]
    assert(mRes,string.format("ranse %s error %s %s %s",sPart,pid,iColor,iShape))
    if not ValidColor(mRes.colorlist,iColor) then
        oNotifyMgr:Notify(pid,GetText(3007))
        return
    end
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    local iCurColor = oWaiGuan:GetClothesPartCurColor(iPart)
    if iColor == iCurColor then
        return true , {}
    end
    local mResult = GetResume(mRes,iColor)
    assert(mResult,string.format("ransehair error %s %s %s",pid,iColor,iShape))
    local iSilver = mResult.silver
    local itemlist = mResult.itemlist
    local iGold = mResult.gold
    local sReason = oWaiGuan:GetResumeReason(iPart, iFlag)
    local mRetCost = {}
    if iFlag and iFlag > 0 then
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["gold"] = iGold
        mNeedCost["item"] = itemlist
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true, cancel_chat = true})
        if not bSucc then return end
        mRetCost["silver"] = mTrueCost["silver"] or 0
        mRetCost["gold"] = mTrueCost["gold"] or 0
        mRetCost["goldcoin"] = mTrueCost["goldcoin"] or 0
        mRetCost["itemlist"] = {}
        for iSid, iAmount in pairs(mTrueCost["item"]) do
            mRetCost["itemlist"][iSid] = iAmount
        end
    else
        if iSilver>0 then
            if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
                return
            end
        end
        if iGold>0 then
            if not oPlayer.m_oActiveCtrl:ValidGold(iGold) then
                return
            end
        end
        for itemsid,iAmount in pairs(itemlist) do
            local iCurAmount = oPlayer.m_oItemCtrl:GetItemAmount(itemsid)
            local itemobj = global.oItemLoader:GetItem(itemsid)
            if iCurAmount<iAmount then
                local sMsg = GetText(2005)
                sMsg = global.oToolMgr:FormatColorString(sMsg, {name = itemobj:Name()})
                oNotifyMgr:Notify(pid,sMsg)
                return
            end
        end
        for itemsid,iAmount in pairs(itemlist) do
            if not oPlayer:RemoveItemAmount(itemsid,iAmount, sReason,{cancel_chat = true,cancel_tip = true}) then 
                return 
            end
        end
        if iSilver >0 then
            oPlayer.m_oActiveCtrl:ResumeSilver(iSilver, sReason,{cancel_chat = true,cancel_tip = true})
        end
        if iGold >0 then
            oPlayer.m_oActiveCtrl:ResumeGold(iGold, sReason,{cancel_chat = true,cancel_tip = true})
        end
        mRetCost = mResult
    end
    oWaiGuan:SetClothesPartColor(iPart, iColor)
    -- oPlayer:SyncModelInfo()
    return true,mRetCost
end

function OpenShiZhuang(oPlayer,iSZ,iType)
    local oNotifyMgr = global.oNotifyMgr
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer,true) then   
        local sMsg = GetText(3006)
        local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
        sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
        oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
        return
    end
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local iShape = oPlayer:GetOriginShape()
    local mRes1 = res["daobiao"]["ranse"]["sz_basic"][iShape]["szlist"]
    assert(mRes1,string.format("OpenShiZhuang  %s %s %s %s",pid,iSZ,iType,iShape))
    if not extend.Array.find(mRes1,iSZ) then
        assert(nil,string.format("OpenShiZhuang  %s %s %s %s",pid,iSZ,iType,iShape))
        return
    end
    local mRes2 = res["daobiao"]["ranse"]["shizhuang"][iSZ]
    assert(mRes2,string.format("OpenShiZhuang  %s %s %s %s",pid,iSZ,iType,iShape))
    assert((iType==TYPE_FOREVER or iType == TYPE_SEVEN),string.format("OpenShiZhuang  %s %s %s",pid,iSZ,iType))
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    local szobj = oWaiGuan:GetShiZhuang(iSZ)
    if szobj and szobj:IsForever() then
        oNotifyMgr:Notify(pid,GetText(3008))
        return
    end

    if iType == TYPE_SEVEN then
        local iGoldCoin = mRes2.seven
        if not oPlayer:ValidGoldCoin(iGoldCoin) then
            return
        end
        if not szobj then
            szobj = NewShiZhuang(iSZ)
        end
        oPlayer:ResumeGoldCoin(iGoldCoin,"shizhuang_seven")
        szobj:UpdateOpenTime()
        oWaiGuan:SetShiZhuang(szobj)
        oWaiGuan:SetCurSZ(szobj:SZID())
        oPlayer:SyncModelInfo()
        oWaiGuan:GS2CRefreshShiZhuang(iSZ)
        oNotifyMgr:Notify(pid,GetText(3009))
    elseif iType == TYPE_FOREVER then
        local iGoldCoin = mRes2.forever
        if not oPlayer:ValidGoldCoin(iGoldCoin) then
            return
        end
        if not szobj then
            szobj = NewShiZhuang(iSZ)
        end
        oPlayer:ResumeGoldCoin(iGoldCoin,"shizhuang_forever")
        szobj:SetForever()
        oWaiGuan:SetShiZhuang(szobj)
        oWaiGuan:SetCurSZ(szobj:SZID())
        oPlayer:SyncModelInfo()
        oWaiGuan:GS2CRefreshShiZhuang(iSZ)
        oNotifyMgr:Notify(pid,GetText(3009))
    end
end

function SetCurSZ(oPlayer,iSZ)
    local oNotifyMgr = global.oNotifyMgr
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer,true) then   
        local sMsg = GetText(3006)
        local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
        sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
        oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
        return
    end
    --print("SetCurSZ",iSZ)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local iShape = oPlayer:GetOriginShape()
    local mRes1 = res["daobiao"]["ranse"]["sz_basic"][iShape]["szlist"]
    assert(mRes1,string.format("SetCurSZ  %s %s %s",pid,iSZ,iShape))
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    if iSZ == 0 then
        oWaiGuan:SetCurSZ(SZ_DEFAULT)
        oPlayer:SyncModelInfo()
        oNotifyMgr:Notify(pid,GetText(3010))
        oPlayer:Send("GS2CRefreshShiZhuang",{szobj=oWaiGuan:PackBaseColor()})
        return
    end

    if not extend.Array.find(mRes1,iSZ) then
        assert(nil,string.format("SetCurSZ  %s %s %s",pid,iSZ,iShape))
        return
    end
    local mRes2 = res["daobiao"]["ranse"]["shizhuang"][iSZ]
    assert(mRes2,string.format("SetCurSZ  %s %s %s",pid,iSZ,iShape))

    
    local szobj = oWaiGuan:GetShiZhuang(iSZ)
    if not szobj then
        oNotifyMgr:Notify(pid,GetText(3011))
        return
    end
    if szobj:IsValidUse() then
        oWaiGuan:SetCurSZ(iSZ)
        oNotifyMgr:Notify(pid,GetText(3010))
        oPlayer:SyncModelInfo()
        oWaiGuan:GS2CRefreshShiZhuang(iSZ)
    else
        oNotifyMgr:Notify(pid,GetText(3012))
    end
end

function CombineCost(iGold, iSilver, iGoldCoin, mItem, mCost)
    mCost = mCost or {}
    iGold = iGold + (mCost.gold or 0)
    iSilver = iSilver+ (mCost.silver or 0)
    for iSid, iAmount in pairs(mCost.itemlist or {}) do
        mItem[iSid] = (mItem[iSid] or 0) + iAmount 
    end
    return iGold, iSilver, iGoldCoin, mItem
end

function SetShiZhuangRanse(oPlayer, iSZ, iClothcolor, iHaircolor, iPantcolor, iFlag)
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer,true) then   
        local sMsg = GetText(3006)
        local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
        sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    local oShiZhuang = oWaiGuan:GetShiZhuang(iSZ)
    if not oShiZhuang then
        oPlayer:NotifyMessage(GetText(3011))
        return
    end

    local bSucc = true
    local iGold, iSilver, iGoldCoin, mItem = 0, 0, 0, {}
    if iHaircolor and oShiZhuang:GetCurHair() ~= iHaircolor then
        local bResult ,mResult = SetShiZhuangRansePart(oPlayer, oShiZhuang, CLOTHES_PART.HAIR, iHaircolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end
    if iClothcolor and oShiZhuang:GetCurClothes() ~= iClothcolor then
        local bResult ,mResult = SetShiZhuangRansePart(oPlayer, oShiZhuang, CLOTHES_PART.CLOTHES, iClothcolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end
    if iPantcolor and oShiZhuang:GetCurPant() ~= iPantcolor then
        local bResult ,mResult = SetShiZhuangRansePart(oPlayer, oShiZhuang, CLOTHES_PART.PANT, iPantcolor, iFlag)
        if not bResult then
            bSucc = false
        else
            iGold, iSilver, iGoldCoin, mItem = CombineCost(iGold, iSilver, iGoldCoin, mItem, mResult)
        end    
    end

    if bSucc then
        local oToolMgr = global.oToolMgr
        local oChatMgr = global.oChatMgr
        oPlayer:NotifyMessage("染色成功")
        if iSilver>0 then
            local sMsg = oToolMgr:FormatColorString("你消耗了#silver银币", {silver = iSilver})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        if iGold>0 then
            local sMsg = oToolMgr:FormatColorString("你消耗了#gold金币", {gold = iGold})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        for iSid, iAmount in pairs(mItem) do
            local oItem = oItemLoader:GetItem(iSid)
            local sMsg = oToolMgr:FormatColorString("消耗#amount个#item", {amount = iAmount, item = oItem:TipsName()})
            oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        oWaiGuan:GS2CRefreshShiZhuang(iSZ)
        if oWaiGuan:GetCurSZ() == iSZ then
            oPlayer:SyncModelInfo()
        end
    end
end

-- sPart 是 hair, pant, clothes 中的一种
function SetShiZhuangRansePart(oPlayer, oShiZhuang, iPart, iColor, iFlag)
    local sPart = res["daobiao"]["ranse"]["ranse_part"][iPart]["part"]
    if not sPart then return end

    local iPid = oPlayer:GetPid()
    local iSZ = oShiZhuang:SZID()
    local mShiZhuang = res["daobiao"]["ranse"]["shizhuang"][iSZ] or {}
    local iShape = mShiZhuang["model"]
    local mRes = res["daobiao"]["ranse"][sPart][iShape]
    assert(mRes,string.format("ranse %s error %s %s %s",sPart,iPid,iColor,iSZ))
    if not ValidColor(mRes.colorlist, iColor) then
        oPlayer:NotifyMessage(GetText(3007))
        return
    end

    local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
    local iCurColor = oShiZhuang:GetClothesPartCurColor(iPart)
    if iColor == iCurColor then
        return true , {}
    end
    local mResult = GetResume(mRes,iColor)
    assert(mResult,string.format("ransehair error %s %s %s",pid,iColor,iShape))

    local iSilver = mResult.silver
    local itemlist = mResult.itemlist
    local iGold = mResult.gold
    local sReason = oWaiGuan:GetResumeReason(iPart, iFlag)
    local mRetCost = {}
    if iFlag and iFlag > 0 then
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["gold"] = iGold
        mNeedCost["item"] = itemlist
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true, cancel_chat = true})
        if not bSucc then return end
        mRetCost["silver"] = mTrueCost["silver"] or 0
        mRetCost["gold"] = mTrueCost["gold"] or 0
        mRetCost["goldcoin"] = mTrueCost["goldcoin"] or 0
        mRetCost["itemlist"] = {}
        for iSid, iAmount in pairs(mTrueCost["item"]) do
            mRetCost["itemlist"][iSid] = iAmount
        end
    else
        if iSilver>0 then
            if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
                return
            end
        end
        if iGold>0 then
            if not oPlayer.m_oActiveCtrl:ValidGold(iGold) then
                return
            end
        end
        for itemsid,iAmount in pairs(itemlist) do
            local iCurAmount = oPlayer.m_oItemCtrl:GetItemAmount(itemsid)
            local itemobj = global.oItemLoader:GetItem(itemsid)
            if iCurAmount<iAmount then
                local sMsg = GetText(2005)
                sMsg = global.oToolMgr:FormatColorString(sMsg, {name = itemobj:Name()})
                oPlayer:NotifyMessage(sMsg)
                return
            end
        end
        for itemsid,iAmount in pairs(itemlist) do
            if not oPlayer:RemoveItemAmount(itemsid,iAmount, sReason,{cancel_chat = true,cancel_tip = true}) then 
                return 
            end
        end
        if iSilver >0 then
            oPlayer.m_oActiveCtrl:ResumeSilver(iSilver, sReason,{cancel_chat = true,cancel_tip = true})
        end
        if iGold >0 then
            oPlayer.m_oActiveCtrl:ResumeGold(iGold, sReason,{cancel_chat = true,cancel_tip = true})
        end
        mRetCost = mResult
    end
    oShiZhuang:SetClothesPartColor(iPart, iColor)
    return true,mRetCost
end

-- -------------delete------------
-- function UnLockSZRanse(oPlayer,iSZ,iColor, iFlag)
--     local oNotifyMgr = global.oNotifyMgr
--     if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer,true) then   
--         local sMsg = GetText(3006)
--         local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
--         sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
--         oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
--         return
--     end
--     local pid = oPlayer:GetPid()
--     local oNotifyMgr = global.oNotifyMgr
--     local iShape = oPlayer:GetOriginShape()
--     local mRes1 = res["daobiao"]["ranse"]["sz_basic"][iShape]["szlist"]
--     assert(mRes1,string.format("UnLockSZRanse  %s %s %s",pid,iSZ,iShape))
--     if not extend.Array.find(mRes1,iSZ) then
--         assert(nil,string.format("UnLockSZRanse  %s %s %s",pid,iSZ,iShape))
--         return
--     end
--     local mRes2 = res["daobiao"]["ranse"]["shizhuang"][iSZ]
--     assert(mRes2,string.format("UnLockSZRanse  %s %s %s",pid,iSZ,iShape))

--     if not ValidColor(mRes2.colorlist,iColor) then
--         oNotifyMgr:Notify(pid,GetText(3007))
--         return
--     end
--     local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
--     local szobj = oWaiGuan:GetShiZhuang(iSZ)
--     if not szobj then
--         oNotifyMgr:Notify(pid,GetText(3011))
--         return 
--     end
--     if not szobj:IsValidUse() then
--         oNotifyMgr:Notify(pid,GetText(3012))
--         return 
--     end

--     if szobj:HasColor(iColor) then
--         oNotifyMgr:Notify(pid,GetText(1008))
--         return
--     end
--     local mResult = GetResume(mRes2,iColor)
--     assert(mResult,string.format("ransehair error %s %s %s",pid,iColor,iShape))
--     local iSilver = mResult.silver
--     local itemlist = mResult.itemlist
--     local iGold = mResult.gold
--     local sReason
--     local mCostLog = {}
--     if iFlag and iFlag > 0 then
--         sReason = "快捷时装染色"
--         local mNeedCost = {}
--         mNeedCost["silver"] = iSilver
--         mNeedCost["gold"] = iGold
--         mNeedCost["item"] = itemlist
--         local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {})
--         if not bSucc then return end

--         mCostLog = analylog.FastCostLog(mTrueCost)
--     else
--         sReason = "时装染色"
--         if iSilver>0 then
--             if not oPlayer.m_oActiveCtrl:ValidSilver(iSilver) then
--                 return
--             end
--         end
--         if iGold>0 then
--             if not oPlayer.m_oActiveCtrl:ValidGold(iGold) then
--                 return
--             end
--         end
--         for itemsid,iAmount in pairs(itemlist) do
--             local iCurAmount = oPlayer.m_oItemCtrl:GetItemAmount(itemsid)
--             local itemobj = global.oItemLoader:GetItem(itemsid)
--             if iCurAmount<iAmount then
--                 local sMsg = GetText(2005)
--                 sMsg = global.oToolMgr:FormatColorString(sMsg, {name = itemobj:Name()})
--                 oNotifyMgr:Notify(pid,sMsg)
--                 return
--             end
--         end
--         for itemsid,iAmount in pairs(itemlist) do
--             if not oPlayer:RemoveItemAmount(itemsid,iAmount, sReason) then
--                 mCostLog[itemsid] = iAmount
--                 return 
--             end
--         end
--         if iSilver >0 then
--             oPlayer.m_oActiveCtrl:ResumeSilver(iSilver, sReason)
--             mCostLog[gamedefines.MONEY_TYPE.SILVER] = iSilver
--         end
--         if iGold >0 then
--             oPlayer.m_oActiveCtrl:ResumeGold(iGold, sReason)
--             mCostLog[gamedefines.MONEY_TYPE.GOLD] = iGold
--         end
--     end
--     szobj:AddColor(iColor)
--     szobj:SetCurColor(iColor)
--     oPlayer:SyncModelInfo()
--     oWaiGuan:GS2CRefreshShiZhuang(iSZ)
--     oNotifyMgr:Notify(pid,GetText(2001))

--     analylog.LogSystemInfo(oPlayer, "player_sz_ranse", nil, mCostLog)
-- end

-- function SetSZColor(oPlayer,iSZ,iColor)
--     local oNotifyMgr = global.oNotifyMgr
--     if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer,true) then   
--         local sMsg = GetText(3006)
--         local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
--         sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
--         oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
--         return
--     end
--     --print("SetSZColor",iSZ,iColor)
--     local pid = oPlayer:GetPid()
--     local oNotifyMgr = global.oNotifyMgr
--     local iShape = oPlayer:GetOriginShape()
--     local mRes1 = res["daobiao"]["ranse"]["sz_basic"][iShape]["szlist"]
--     assert(mRes1,string.format("SetSZColor  %s %s %s",pid,iSZ,iShape))
--     if not extend.Array.find(mRes1,iSZ) then
--         assert(nil,string.format("SetSZColor  %s %s %s",pid,iSZ,iShape))
--         return
--     end
--     local mRes2 = res["daobiao"]["ranse"]["shizhuang"][iSZ]
--     assert(mRes2,string.format("SetSZColor  %s %s %s",pid,iSZ,iShape))



--     if not ValidColor(mRes2.colorlist,iColor) then
--         oNotifyMgr:Notify(pid,GetText(3007))
--         return
--     end

--     local oWaiGuan = oPlayer.m_oBaseCtrl.m_oWaiGuan
--     local szobj = oWaiGuan:GetShiZhuang(iSZ)
--     if not szobj then
--         oNotifyMgr:Notify(pid,GetText(3011))
--         return 
--     end
--     if not szobj:IsValidUse() then
--         oNotifyMgr:Notify(pid,GetText(3012))
--         return 
--     end

--     if szobj:GetCurColor() == iColor then
--         oNotifyMgr:Notify(pid,GetText(3013))
--         return
--     end

--     if iColor == 0 then
--         szobj:SetCurColor(iColor)
--         oWaiGuan:GS2CRefreshShiZhuang(iSZ)
--         oPlayer:SyncModelInfo()
--         oNotifyMgr:Notify(pid,GetText(3010))
--         return
--     end

--     if not szobj:HasColor(iColor) then
--         oNotifyMgr:Notify(pid,GetText(3014))
--         return
--     end

--     szobj:SetCurColor(iColor)
--     oPlayer:SyncModelInfo()
--     oWaiGuan:GS2CRefreshShiZhuang(iSZ)
--     oNotifyMgr:Notify(pid,GetText(3010))
-- end




