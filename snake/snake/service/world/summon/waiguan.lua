local global = require "global"
local extend = require "base/extend"
local res = require "base.res"
local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))


function NewWaiGuan(...)
    return CWaiGuan:New(...)
end

CWaiGuan = {}
CWaiGuan.__index = CWaiGuan
inherit(CWaiGuan, datactrl.CDataCtrl)

function CWaiGuan:New(summid)
    local o = super(CWaiGuan).New(self, {summid = summid})
    o.m_iCurColor = 0
    return o
end

function CWaiGuan:Save()
    local mData = {}
    mData["curcolor"] = self.m_iCurColor
    return mData
end

function CWaiGuan:Load(mData)
    mData = mData or {}
    self.m_iCurColor = mData["curcolor"] or 0
end

function CWaiGuan:GetCurColor()
    return self.m_iCurColor
end

function CWaiGuan:SetCurColor(iColor)
    self:Dirty()
    self.m_iCurColor = iColor
end

function CWaiGuan:CleanAll()
    self:Dirty()
    self.m_iCurColor = 0
end

function GetText(iText)
    return res["daobiao"]["ranse"]["text"][iText]["text"]
end

function CleanAll(oPlayer)
    for _, oSummon in pairs(oPlayer.m_oSummonCtrl.m_mSummons) do
        local oWaiGuan = oSummon.m_oWaiGuan
        oWaiGuan:CleanAll()
    end
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
    local default_resume = mRes.dresume[1]
    assert(resumelist,"GetResume")
    assert(iColor,"GetResume")
    local mResult = nil
    if iColor >0 then
        for _,mResume in pairs(resumelist) do
            if mResume.color == iColor then
                mResult = {}
                mResult.gold = mResume.gold
                mResult.silver = mResume.silver
                mResult.itemlist = {}
                for itemsid,amount in string.gmatch(mResume.item,"(%d+)*(%d+)") do
                    mResult.itemlist[tonumber(itemsid)]  = tonumber(amount)
                end
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

function UnLockSummonColor(oPlayer,iSumid,iColor,iFlag)
    local oNotifyMgr = global.oNotifyMgr
    if not global.oToolMgr:IsSysOpen("RANSE",oPlayer,true) then   
        local sMsg = res["daobiao"]["ranse"]["text"][3005]["text"]
        local LIMIT_RANSE_GRADE = res["daobiao"]["open"]["RANSE"]["p_level"]
        sMsg = string.gsub(sMsg,"#level",LIMIT_RANSE_GRADE)
        oNotifyMgr:Notify(oPlayer:GetPid(),sMsg)
        return
    end
    --print("UnLockSummonColor",iColor)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local sumobj = oPlayer.m_oSummonCtrl:GetSummon(iSumid)
    if not sumobj then
        oNotifyMgr:Notify(pid,GetText(1009))
        return 
    end
    if sumobj:IsWild() then
        return
    end
    local oWaiGuan = sumobj.m_oWaiGuan
    local iShape = sumobj:Shape()
    local mRes = res["daobiao"]["ranse"]["summon"][iShape]
    assert(mRes,string.format("ransesum error %s %s",pid,iShape))
    iColor = RandomColor(mRes,oWaiGuan:GetCurColor())
    --print("UnLockSummonColor",iColor)
    if not ValidColor(mRes.colorlist,iColor) then
        oNotifyMgr:Notify(pid,"无此颜色")
        return
    end
    

    if iColor == oWaiGuan:GetCurColor() then
        oNotifyMgr:Notify(pid,"此颜色已经染")
        return
    end

    local mResult = GetResume(mRes,iColor)
    assert(mResult,string.format("ransesum error %s %s %s",pid,iColor,iShape))
    local iSilver = mResult.silver
    local itemlist = mResult.itemlist
    local iGold = mResult.gold
    local sReason
    local mCostLog = {}
    if iFlag and iFlag > 0 then
        local sReason = "宠物快捷染色"
        local mNeedCost = {}
        mNeedCost["silver"] = iSilver
        mNeedCost["item"] = {}
        for itemsid, iAmount in pairs(itemlist) do
            mNeedCost["item"][itemsid] = iAmount
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end

        mCostLog = analylog.FastCostLog(mTrueCost)
    else
        sReason = "宠物染色"
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
            if not oPlayer:RemoveItemAmount(itemsid,iAmount, sReason) then
                mCostLog[itemsid] = iAmount 
                return 
            end
        end
        if iSilver >0 then
            oPlayer.m_oActiveCtrl:ResumeSilver(iSilver, sReason)
            mCostLog[gamedefines.MONEY_TYPE.SILVER] = iSilver 
        end
        if iGold >0 then
            oPlayer.m_oActiveCtrl:ResumeGold(iGold, sReason)
            mCostLog[gamedefines.MONEY_TYPE.GOLD] = iGold 
        end
    end
    oWaiGuan:SetCurColor(iColor)
    sumobj:PropChange("model_info")
    oPlayer:PropChange("followers")
    oPlayer:SyncSceneInfo({followers=oPlayer:GetFollowers()})
    oNotifyMgr:Notify(pid,GetText(2012))

    analylog.LogSystemInfo(oPlayer, "summon_sz_ranse", nil, mCostLog)
end

function RandomColor(mRes,iCurColor)
    local colorlist = mRes.colorlist
    local lrand = {0,}
    if iCurColor == 0 then
        lrand = {}
    end
    for index , mInfo  in ipairs(colorlist) do
        if mInfo.color ~= iCurColor then
            table.insert(lrand,mInfo.color)
        end
    end
    local iColor = extend.Random.random_choice(lrand)
    return iColor
end