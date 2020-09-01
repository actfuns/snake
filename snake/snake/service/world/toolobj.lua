--import module

local global = require "global"
local extend = require "base.extend"
local router = require "base.router"

local util = import(lualib_path("public.util"))
local gamedefines = import(lualib_path("public.gamedefines"))
local testdefines = import(service_path("defines/testdefines"))

local string = string

function NewToolMgr(...)
    local oMgr = CToolMgr:New(...)
    return oMgr
end

CToolMgr = {}
CToolMgr.__index = CToolMgr
inherit(CToolMgr, logic_base_cls())

function CToolMgr:New()
    local o = super(CToolMgr).New(self)
    o.m_mSysOpenStatus = {}
    return o
end

function CToolMgr:FormatColorString(sText, mReplace)
    return util.FormatColorString(sText, mReplace, true)
end

function CToolMgr:FormatString(sText, mReplace, bColor)
    return util.FormatString(sText, mReplace, bColor)
end

function CToolMgr:GetTextData(iText, tUrl)
    return util.GetTextData(iText, tUrl)
end

function CToolMgr:GetSystemText(tUrl, iText, mReplace)
    local sText = util.GetTextData(iText, tUrl)
    if not sText or not mReplace then
        return sText
    end
    sText = util.FormatColorString(sText, mReplace, true)
    return sText
end

function CToolMgr:GetFigureShape(iFigureId)
    assert(iFigureId, "model figureid nil")
    local res = require "base.res"
    local mData = table_get_depth(res, {"daobiao", "modelfigure", iFigureId})
    assert(mData, string.format("model figureid unconfiged, figureid:%s", iFigureId))
    return mData.model
end

function CToolMgr:GetFigureModelData(iFigureId, bComplex)
    assert(iFigureId, "model figureid nil")
    local res = require "base.res"
    local mData = table_get_depth(res, {"daobiao", "modelfigure", iFigureId})
    assert(mData, string.format("model figureid unconfiged, figureid:%s", iFigureId))
    local mRet = {
        figure = iFigureId,
    }
    if not bComplex then
        return mRet
    end

    local mColor = mData.mutate_color
    if mColor then
        mColor = table_deep_copy(mColor)
    end
    mRet.shape = mData.model
    mRet.scale = mData.scale
    mRet.adorn = mData.ornament
    mRet.weapon = mData.wpmodel
    mRet.color = mColor
    mRet.scale = mData.scale
    mRet.mutate_texture = mData.mutate_texture
    return mRet
end

function CToolMgr:GetSummonText(iText, mData)
    local sMsg = self:GetTextData(iText, {"summon", "text"})
    return self:FormatColorString(sMsg, mData or {})
end

function CToolMgr:GetSysOpenPlayerGrade(sSys)
    local res = require "base.res"
    return res["daobiao"]["open"][sSys]["p_level"]
end

-- 判断是否开放
-- mArgs:　
--  close_tips:系统关闭提示
--  plevel_tips:玩家等级不足提示
--  glevel_tips:服务器等级不足提示
function CToolMgr:IsSysOpen(sSys, oPlayer, bSilent, mArgs)
    local mData = self:GetSysOpenConfig()[sSys]
    assert(mData, string.format("cant find openSys err:%s", sSys))

    mArgs = mArgs or {}
    local iKsOpen = mData["ks_open"] or 0
    if iKsOpen <= 0 and is_ks_server() then
        if oPlayer then
            if not bSilent then
                local sMsg = mArgs.ks_close_tips or self:GetTextData(1109)
                oPlayer:NotifyMessage(self:FormatColorString(sMsg, {name = mData["name"]}))
            end
        end
        return false
    end
    if self:GetSysOpenStatus(sSys) == 0 then
        if oPlayer then
            if not bSilent then
                local sMsg = mArgs.close_tips or self:GetTextData(1101)
                oPlayer:NotifyMessage(self:FormatColorString(sMsg, {name = mData["name"]}))
            end
        end
        return false
    end
    
    if sSys == "FOBID_OPEN_CHECK_TASK" then
        return true
    end
    if sSys == "RIDE_SYS" then
        if oPlayer and oPlayer.m_oRideCtrl:GetRideCnt() > 0 then
            return true
        end
    end

    local oWorldMgr = global.oWorldMgr
    local iServerGrade = oWorldMgr:GetServerGrade()
    if oPlayer then
        iServerGrade = oPlayer:GetServerGrade()
    end
    if iServerGrade < mData["g_level"] then
        if oPlayer and not bSilent then
            local sMsg = mArgs.glevel_tips or self:GetTextData(1103)
            oPlayer:NotifyMessage(sMsg)
        end
        return false
    end

    if oPlayer then
        if oPlayer:Query("testman", 0) == 99 then
            return true
        end
        if oPlayer.m_oBaseCtrl.m_oTestCtrl:GetTesterKey(testdefines.TESTER_KEY.ALL_SYS_OPEN) then
            return true
        end
        if oPlayer:GetGrade() < mData["p_level"] then
            if not bSilent then
                local sMsg = mArgs.plevel_tips or self:GetTextData(1102)
                local mReplace = {level=mData["p_level"], name=mData["name"]}
                oPlayer:NotifyMessage(self:FormatColorString(sMsg, mReplace))
            end
            return false
        end
        
        if not oPlayer:Query("skip_open_check_task_lock") and (oPlayer:Query("open_check_task_lock") or not self:IsSysOpen("FOBID_OPEN_CHECK_TASK", nil, true)) then
            local iStoryLock = mData["task_lock"]
            if iStoryLock and iStoryLock > 0 then
                if oPlayer.m_oTaskCtrl:IsTagLocked(iStoryLock) then
                    if not bSilent then
                        local sMsg = mArgs.task_tips or self:GetTextData(1100)
                        oPlayer:NotifyMessage(self:FormatColorString(sMsg, {name = mData["name"]}))
                    end
                    return false
                end
            end
        end
    end
    return true
end

function CToolMgr:GetSysOpenConfig()
    local res = require "base.res"
    return res["daobiao"]["open"]
end

function CToolMgr:GetSysOpenStatus(sSys)
    local iStatus = self.m_mSysOpenStatus[sSys]
    if iStatus then return iStatus end

    local mConfig = self:GetSysOpenConfig()[sSys]
    if not mConfig then return 0 end

    return mConfig["open_sys"]
end

function CToolMgr:GetAllSysOpenStatus()
    local mConfig = self:GetSysOpenConfig()
    local lSysOpen = {}
    for _,v in pairs(mConfig) do
        table.insert(lSysOpen, {
            stype = v.stype,
            name = v.name,
            desc = v.desc,
            level = v.p_level,
            status = self:GetSysOpenStatus(v.stype),
        })
    end
    return lSysOpen
end

function CToolMgr:SetSysOpenStatus(lSysOpen, iStatus)
    local bOpen = (iStatus > 0)
    for _,sSys in pairs(lSysOpen) do
        if bOpen then
            self.m_mSysOpenStatus[sSys] = nil
        else
            self.m_mSysOpenStatus[sSys] = 0
        end
        global.oSysOpenMgr:TriggerEvent(gamedefines.EVENT.SYS_OPEN_STATUS_CHANGE, {
            sys=sSys, 
            open=self:IsSysOpen(sSys),
        })
    end
    if bOpen then
        global.oSysOpenMgr:BroadCastOpenSys(lSysOpen)
    else
        global.oSysOpenMgr:BroadCastCloseSys(lSysOpen)
    end
end

function CToolMgr:GenRandomRoleName()
    local res = require "base.res"
    local mNamesInfo = res["daobiao"]["random_rolename"]
    local iSex = math.random(1, 2)
    local lNameList
    if iSex == 1 then
        lNameList = mNamesInfo.male_name
    else
        lNameList = mNamesInfo.female_name
    end
    return extend.Random.random_choice(mNamesInfo.first_name) .. extend.Random.random_choice(lNameList)
end

function CToolMgr:GenRandomNpcName()
    local res = require "base.res"
    local mNamesInfo = res["daobiao"]["random_npcname"]
    local fRandoutName = function(sNameType)
        local iRandSeed = math.random(1, mNamesInfo.size)
        local mNames = mNamesInfo[sNameType]
        if #mNames < iRandSeed then
            return ""
        end
        return mNames[iRandSeed]
    end
    local sResName = ""
    sResName = sResName .. fRandoutName("first_name")
    sResName = sResName .. fRandoutName("middle_name")
    sResName = sResName .. fRandoutName("last_name")
    return sResName
end

-- function CToolMgr:RandomMapValue(mMap)
--     if not mMap then
--         return nil
--     end
--     local mValues = table_value_list(mMap)
--     local iSize = #mValues
--     if iSize == 0 then
--         return nil
--     elseif iSize == 1 then
--         return mValues[1]
--     end
--     return mMap[math.random(iSize)]
-- end

function CToolMgr:SelectWorldOnlinePlayer(fCheck)
    -- 在线玩家
    -- 先随机并在命中一个玩家后直接返回
    local mOnlinePlayers = global.oWorldMgr:GetOnlinePlayerList()
    local iSelectedId, oSelectedPlayer = next(extend.Table.randomfiltermap(mOnlinePlayers, 1, fCheck))
    return oSelectedPlayer
end

function CToolMgr:SelectOrgOnlinePlayer(iOrgId, fCheck)
    -- 在线帮内玩家
    local mOnlinePlayers = global.oOrgMgr:GetOrgOnlineMembers(iOrgId)
    -- local mSelecteds = extend.Table.filtermap(mOnlinePlayers, fCheck)
    -- return self:RandomMapValue(mSelecteds)
    local iSelectedId, oSelectedPlayer = next(extend.Table.randomfiltermap(mOnlinePlayers, 1, fCheck))
    return oSelectedPlayer
end

function CToolMgr:GetSchoolTeacher(iSchool)
    local res = require "base.res"
    local mData = res["daobiao"]["school_npc"][iSchool]
    if not mData then
        return 5220
    end
    assert(mData, "school npc data nil, iSchool=" .. iSchool)
    return mData.tutorid
end

function CToolMgr:ConvertSeconds(iSeconds)
    local iTolMins = math.floor(iSeconds / 60)
    local iHour = math.floor(iTolMins / 60)
    local iMins = iTolMins - iHour * 60
    local iSec = iSeconds - iMins * 60 - iHour * 3600
    return iHour, iMins, iSec
end

function CToolMgr:FormatTime2BanChat(iSeconds)
    local iHour, iMins, iSec = self:ConvertSeconds(iSeconds)
    if iHour == 0 and iMins == 0 then
        iMins = 1
    end
    return string.format("%02d", iHour), string.format("%02d", iMins), string.format("%02d", iSec)
end

function CToolMgr:ChangeGold2GoldCoin(iGold)
    return math.ceil(iGold / 100)
end

function CToolMgr:ExecuteList(lArray, iMaxSeq, iDelay, iCnt, sKey, callback, endfunc)
    self:DelTimeCb(sKey)

    if iCnt*iMaxSeq > #lArray or #lArray <= 0 then
        if endfunc then
            safe_call(endfunc)
        end
        return
    end

    local iStart = iCnt*iMaxSeq + 1
    local iEnd = math.min((iCnt+1)*iMaxSeq, #lArray)
    for i = iStart, iEnd do
        safe_call(callback, lArray[i])
    end
    local func = function()
        global.oToolMgr:ExecuteList(lArray, iMaxSeq, iDelay, iCnt+1, sKey, callback, endfunc)
    end
    self:AddTimeCb(sKey, iDelay, func)
end

function CToolMgr:HasTrueItemByReward(sHDName,iRewardIdx)
    local res = require "base.res"
    local mRewardData = res["daobiao"]["reward"][sHDName]["reward"][iRewardIdx]
    assert(mRewardData,string.format("CToolMgr:HasTrueItemByReward1 err:%s %d", sHDName, iRewardIdx))
    local mItemRewardData = res["daobiao"]["reward"][sHDName]["itemreward"]
    assert(mItemRewardData,string.format("CToolMgr:HasTrueItemByReward2 err:%s %d", sHDName, iRewardIdx))
    if #mRewardData.item<=0 then
        return false
    end
    for _,itemreward in ipairs(mRewardData.item) do
        local itemlist = mItemRewardData[itemreward]
        assert(itemlist,string.format("CToolMgr:HasTrueItemByReward3 err:%s %d %d", sHDName, iRewardIdx,itemreward))
        for _,iteminfo in ipairs(itemlist) do
            local sid = iteminfo.sid
            if tonumber(sid) then
                sid = tonumber(sid)
            else
                sid,_ = string.match(sid,"(%d+)(.*)")
                sid = tonumber(sid)
            end
            local itemobj = global.oItemLoader:GetItem(sid)
            if itemobj:ItemType()~="virtual" then
                return true 
            end
        end
    end
    return false
end

function CToolMgr:GetItemRewardCnt(sHDName,iRewardIdx)
    local res = require "base.res"
    local mRewardData = res["daobiao"]["reward"][sHDName]["reward"][iRewardIdx]
    assert(mRewardData,string.format("CToolMgr:HasTrueItemByReward1 err:%s %d", sHDName, iRewardIdx))
   local mItemRewardData = res["daobiao"]["reward"][sHDName]["itemreward"]
    assert(mItemRewardData,string.format("CToolMgr:HasTrueItemByReward2 err:%s %d", sHDName, iRewardIdx))

    local iCnt = 0
    for _,itemreward in ipairs(mRewardData.item) do
        local itemlist = mItemRewardData[itemreward]
        assert(itemlist,string.format("CToolMgr:HasTrueItemByReward3 err:%s %d %d", sHDName, iRewardIdx,itemreward))
        local iCnt1=0
        for _,iteminfo in ipairs(itemlist) do
            local sid = iteminfo.sid
            if tonumber(sid) then
                sid = tonumber(sid)
            else
                sid,_ = string.match(sid,"(%d+)(.*)")
                sid = tonumber(sid)
            end
            local itemobj = global.oItemLoader:GetItem(sid)
            if itemobj:ItemType()~="virtual" then
                iCnt1=1
            end
        end
        iCnt = iCnt + iCnt1
    end
    return iCnt
end

function CToolMgr:SysAnnounce(iChat, mReplace)
    local res = require "base.res"
    local mInfo = res["daobiao"]["chuanwen"][iChat]
    if not mInfo then return end

    local sMsg, iHorse = mInfo.content, mInfo.horse_race
    if mReplace then
        sMsg = self:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
end

function CToolMgr:GetInstructionText(iText)
    local res = require "base.res"
    local mRes = res["daobiao"]["instruction"]
    assert(mRes[iText],string.format("%s instruction error",iText))
    return mRes[iText]["desc"]
end

function CToolMgr:PackExchangeData(iMoneyType,iMoneyValue,itemlist)
    local iServerGrade = global.oWorldMgr:GetServerGrade()
    local iNeedGoldCoin = 0
    local iExchangeMoneyValue = 0
    local res = require "base.res"
    local mMoneyRes = res["daobiao"]["exchangemoney"]
    if iMoneyType then
        if iMoneyType ~= gamedefines.MONEY_TYPE.GOLD and iMoneyType ~= gamedefines.MONEY_TYPE.SILVER then
            assert(nil,string.format("PackExchangeData %s",iMoneyType))
        end
        assert(mMoneyRes[iMoneyType],string.format("PackExchangeData %s",iMoneyType))
        assert(iMoneyValue>0,string.format("PackExchangeData %s",iMoneyValue))
        local sFormula = mMoneyRes[iMoneyType].goldcoin
        iNeedGoldCoin =iNeedGoldCoin + formula_string(sFormula,{value = iMoneyValue,SLV = iServerGrade})
        
        local mGoldCoinRes = mMoneyRes[gamedefines.MONEY_TYPE.GOLDCOIN]
        sFormula = nil
        if iMoneyType == gamedefines.MONEY_TYPE.SILVER then
            sFormula = mGoldCoinRes.silver
        elseif iMoneyType == gamedefines.MONEY_TYPE.GOLD then
            sFormula = mGoldCoinRes.gold
        else
            assert(nil,string.format("%s no find",iMoneyType))
        end
        if sFormula then
            iExchangeMoneyValue = math.floor(formula_string(sFormula,{value = iNeedGoldCoin,SLV = iServerGrade}))
        end
    end
    local mFastItem = {}
    if itemlist and next(itemlist) then
        for itemsid,amount in pairs(itemlist) do
            if not mFastItem[itemsid] then
                mFastItem[itemsid] = {}
            end
            mFastItem[itemsid].amount = amount
        end
        local _,iAddGoldCoin = global.oFastBuyMgr:GetFastBuyCost(nil,mFastItem,"exchange")
        iNeedGoldCoin  = iNeedGoldCoin + iAddGoldCoin
    end
    iNeedGoldCoin = math.ceil(iNeedGoldCoin)
    assert(iNeedGoldCoin>0,"PackExchangeData")
    local mData = {}
    local mCopyData = {}
    mData.moneytype = iMoneyType
    mData.moneyvalue = iMoneyValue
    mData.goldcoin = iNeedGoldCoin
    mData.itemlist = itemlist
    mData.exchangemoneyvalue = iExchangeMoneyValue

    mCopyData.moneytype = iMoneyType
    mCopyData.moneyvalue = iMoneyValue
    mCopyData.goldcoin = iNeedGoldCoin
    mCopyData.exchangemoneyvalue = iExchangeMoneyValue
    local mItemlist = {}
    if next(itemlist) then
        for itemsid,amount in pairs(itemlist) do 
            table.insert(mItemlist,{itemsid = itemsid,amount = amount})
        end
    end
    mCopyData.itemlist = mItemlist
    return mData,mCopyData
end

function CToolMgr:TryExchange(oPlayer,PremExchange,mData)
    local iAnswer = mData.answer
    if iAnswer ~=1 then
        return false
    end
    local pid = oPlayer:GetPid()
    --防止回调期间导表改动
    local mExchange,_ = self:PackExchangeData(PremExchange.moneytype,PremExchange.moneyvalue,PremExchange.itemlist)
    local iGoldCoin = mExchange.goldcoin
    local iExchangeMoneyValue = mExchange.exchangemoneyvalue
    if not oPlayer:ValidGoldCoin(iGoldCoin) then
        return  false
    end
    local itemlist = mExchange.itemlist
    local exchangeitemlist = {}
    if itemlist and next(itemlist) then
        for itemsid,amount in pairs(itemlist) do
            local itemobj = global.oItemLoader:ExtCreate(itemsid)
            itemobj:SetAmount(amount)
            itemobj:Bind(pid)
            table.insert(exchangeitemlist,itemobj)
        end
    end
    local sTip = "你的背包已满，请清理后再兑换"
    if #exchangeitemlist>0 and not oPlayer:ValidGiveitemlist(exchangeitemlist,{tip=sTip}) then
        return  false
    end
    local sReason = "exchange"
    local iServerGrade = oPlayer:GetServerGrade()
    assert(iGoldCoin>0)
    oPlayer:ResumeGoldCoin(iGoldCoin,sReason)
    if #exchangeitemlist>0 then
        oPlayer:GiveItemobj(exchangeitemlist,sReason)
    end
    if mExchange.moneytype then
        oPlayer:RewardByType(mExchange.moneytype,iExchangeMoneyValue,sReason)
    end
    return true
end

function CToolMgr:DebugMsg(iPid, sMsg)
    if not is_production_env() then 
        global.oNotifyMgr:Notify(iPid, "【内服提示】:"..sMsg)
    end
end
