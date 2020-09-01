local global = require "global"
local extend = require "base/extend"
local res = require "base.res"
local record = require "public.record"

local loadsummon = import(service_path("summon.loadsummon"))
local waiguan = import(service_path("summon.waiguan"))
local summondefines = import(service_path("summon.summondefines"))

-----------------------------------------------C2GS--------------------------------------------
function C2GSWashSummon(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_XC", oPlayer) then return end

    local oSummonMgr = global.oSummonMgr
    oSummonMgr:WashSummon(oPlayer, mData["summid"], mData["flag"])
end

function C2GSStickSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_JN", oPlayer) then return end
    
    local summid = mData["summid"]
    local itemid = mData["itemid"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:StickSkill(oPlayer, summid, itemid)
end

function C2GSFastStickSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_JN", oplayer) then return end
    local iSummid = mData["summid"]
    local iBookSid = mData["booksid"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:FastStickSkill(oPlayer, iSummid, iBookSid)
end

function C2GSSummonSkillLevelUp(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_JN", oPlayer) then return end

    local summid = mData["summid"]
    local skid = mData["skid"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:SkillLevelUp(oPlayer, summid, skid)
end

function C2GSSummonChangeName(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local name = mData["name"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
        
    local mLog = oSummon:LogData(oPlayer)
    oSummon:SetName(name)
    if oPlayer.m_oSummonCtrl:GetFollowID() == oSummon.m_iID then
        oPlayer.m_oSummonCtrl:SyncSceneInfo()
        oPlayer:PropChange("followers")
    end

    mLog["new_name"] = name
    record.user("summon", "change_name", mLog)
end

function C2GSSummonSetFight(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local iFight = mData["fight"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    global.oSummonMgr:SetFight(oPlayer, oSummon, iFight, true)
end

function C2GSReleaseSummon(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
    
    local oSummonMgr = global.oSummonMgr
    if summondefines.IsImmortalBB(oSummon:Type()) then
        oPlayer:NotifyMessage(oSummonMgr:GetText(2028))
        return
    end 

    local oNotifyMgr = global.oNotifyMgr
    if oPlayer.m_oSummonCtrl:GetFightSummon() == oSummon then
        oPlayer:NotifyMessage(oSummonMgr:GetText(1028))
        return
    end
    if oPlayer.m_oSummonCtrl:GetFollowID() == summid then
        oPlayer.m_oSummonCtrl:UnFollow() 
    end

    local oRide = oPlayer.m_oRideCtrl:GetRide(oSummon:GetBindRide())
    if oRide then
        local iPos = oRide:GetSummonPos(oSummon)
        if iPos then
            oRide:UnControlSummon(iPos)
            oRide:GS2CUpdateRide(oPlayer)
            oPlayer:NotifyMessage(oSummonMgr:GetText(1056, {summon=oSummon:Name()}))
        end
    end

    local mLog = oSummon:LogData(oPlayer)
    record.user("summon", "release_summon", mLog)
    local sSummonName = oSummon:Name()
    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon, "放生", {recevery=true})
    oPlayer:NotifyMessage(oSummonMgr:GetText(2029, {summon=sSummonName}))
end

function C2GSSummonAssignPoint(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local scheme = mData["scheme"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
    
    local tot = 0
    for attr, point in pairs(scheme) do
        tot = tot + point
    end
    if tot > oSummon:Point() then return end

    local mLog = oSummon:LogData(oPlayer)
    mLog["old_point"] = oSummon:Point()

    local lLogAttr = {}
    oSummon:AddPoint(-tot)
    for attr, point in pairs(scheme) do
        local mAttr = {attr=attr, old_point=oSummon:Attribute(attr)}
        oSummon:AddAttribute(attr, point)
        mAttr["new_point"] = oSummon:Attribute(attr)
        table.insert(lLogAttr, mAttr)
    end
    oSummon:Setup()
    oSummon:Refresh()

    mLog["now_point"] = oSummon:Point()
    mLog["sub_point"] = tot
    mLog["assign_point"] = lLogAttr
    record.user("summon", "assign_point", mLog) 
end

function C2GSSummonAutoAssignScheme(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local scheme = mData["scheme"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
        
    local oNotifyMgr = global.oNotifyMgr
    local tot = 0
    for attr, point in pairs(scheme) do
        tot = tot + point
    end

    if tot == 0 then
        oSummon:SetAutoSwitch(0)
        oNotifyMgr:Notify(oPlayer:GetPid(), "已取消自动加点")
        return
    elseif tot % 5 ~= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(), "加点方案必须分配满5点才行哦")
        return
    end
    
    oSummon:SetAutoPointSheme(scheme)
    oSummon:SetAutoSwitch(1)
    oSummon:AutoAssignPoint()
    oSummon:Setup()
    oSummon:Refresh()
    oNotifyMgr:Notify(oPlayer:GetPid(), "已启用自动加点方案")
    
    local mLog = oSummon:LogData(oPlayer)
    record.user("summon", "set_assign_scheme", mLog)
end

function C2GSSummonOpenAutoAssign(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local flag = mData["flag"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    local mLog = oSummon:LogData(oPlayer)    
    oSummon:SetAutoSwitch(flag)
    mLog["open"] = 0
    if flag == 1 then
        mLog["open"] = 1
        oSummon:AutoAssignPoint()
        oSummon:Setup()
        oSummon:Refresh()
    end
    record.user("summon", "open_assign_scheme", mLog)
end

function C2GSSummonRequestAuto(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    local mNet = {}
    mNet["id"] = oSummon.m_iID
    mNet["switch"] = oSummon:IsOpenAutoPoint()
    mNet["scheme"] = oSummon:GetData("autopoint")
    oPlayer:Send("GS2CSummonAutoAssignScheme", mNet)
end

function C2GSBuySummon(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    if oPlayer.m_oSummonCtrl:IsFull() then
        oNotifyMgr:Notify(oPlayer:GetPid(), "携带的宠物数量已经达到上限了")
        return
    end
    local typeid = mData["typeid"]
    mData = res["daobiao"]["summon"]["store"][typeid]
    assert(mData, string.format("buy summon typeid err %d", typeid))

    if oPlayer:GetServerGrade() < mData.slv then
        oNotifyMgr:Notify(oPlayer:GetPid(), "服务器等级不足")
        return
    end
    if oPlayer:GetGrade() < mData.lv then
        oNotifyMgr:Notify(oPlayer:GetPid(), "玩家等级不足")
        return
    end


    local iPrice = mData["price"]
    if not oPlayer:ValidSilver(iPrice) then return end
        
    oPlayer:ResumeSilver(iPrice, "购买宠物")

    local iGrade = math.max(1, mData.usegrade)
    local oSummon = loadsummon.CreateSummon(typeid, iGrade, 1)
    assert(oSummon, string.format("buysummon typeid err:%d", typeid))
    oPlayer.m_oSummonCtrl:AddSummon(oSummon)
    oNotifyMgr:SummonNotify(oPlayer:GetPid(), {sid=typeid, amount=1, type=1})

    local mLogData = oPlayer:LogData()
    mLogData["summon"] = typeid
    mLogData["amount"] = 1
    mLogData["silver"] = iPrice
    record.log_db("economic", "summon_buy", mLogData)
end

function C2GSCombineSummon(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_HC", oPlayer) then return end

    local summid1 = mData["summid1"]
    local summid2 = mData["summid2"]
    local iFlag = mData["flag"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:SummonCombine(oPlayer, summid1, summid2, iFlag)
end

function C2GSSummonFollow(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local flag = mData["flag"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    if flag == 1 then
        oPlayer.m_oSummonCtrl:Follow(summid)
    else
        if oPlayer.m_oSummonCtrl:GetFollowID() ~= summid then
            return
        end
        oPlayer.m_oSummonCtrl:UnFollow()
    end
end

function C2GSUseSummonExpBook(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local iCnt = mData["cnt"]
    local iSid = mData["sid"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    local oSummonMgr = global.oSummonMgr
    oSummonMgr:UseSummonExpBook(oPlayer, oSummon, iSid, iCnt)
end

function C2GSUseAptitudePellet(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_PY", oPlayer) then return end
    local summid = mData["summid"]
    local aptitude = mData["aptitude"]
    local iFlag = mData["flag"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
    
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:UseAptitudePellet(oPlayer, oSummon, aptitude, iFlag)
end

function C2GSUseGrowPellet(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
    
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:UseGrowPellet(oPlayer, oSummon)
end

function C2GSUsePointPellet(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local attr = mData["attr"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
        
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:UsePointPellet(oPlayer, oSummon, attr)
end

function C2GSUseLifePellet(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local cnt = mData["cnt"]
    local itemid = mData["itemid"]
    
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    local oSummonMgr = global.oSummonMgr
    oSummonMgr:UseLifePellet(oPlayer, oSummon, itemid, cnt)
end

function C2GSSummonRestPointUI(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local summid = mData["summid"]
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    local mNet = {}
    mNet["id"] = oSummon.m_iID
    mNet["initaddattr"] = oSummon:GetData("initaddattr", {})
    oPlayer:Send("GS2CSummonInitAttrInfo", mNet)
end

-- function C2GSGetSummonSecProp(oPlayer, mData)
--     local summid = mData["summid"]
--     local mSummon = {}
--     if summid and summid > 0 then
--         local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
--         if not oSummon then return end
            
--         mSummon[summid] = oSummon
--     else    
--         mSummon = oPlayer.m_oSummonCtrl:SummonList()
--     end
    
--     if table_count(mSummon)  <= 0 then 
--         return 
--     end
        
--     local mPropInfo = {}
--     local lSecondProp = {"speed","mag_defense","phy_defense","mag_attack","phy_attack","max_hp", "max_mp"}
--     for id,oSummon in pairs(mSummon) do
--         for _, sProp in pairs(lSecondProp) do
--             local mData = {}
--             local iBase = oSummon:GetBaseAttr(sProp)
--             mData.base = iBase
--             mData.extra = oSummon:QueryApply(sProp) + math.floor(iBase * oSummon:QueryRatioApply(sProp) / 100)
--             -- mData.ratio = oSummon:QueryRatioApply(sProp)
--             mData.summid = id
--             mData.name = sProp
--             table.insert(mPropInfo, mData)
--         end
--     end
--     local mNet = {}
--     mNet["prop_infos"] = mPropInfo
--     oPlayer:Send("GS2CGetSummonSecProp", mNet)
-- end

function C2GSExchangeSummon(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SUMMON_SYS", oPlayer) then return end

    local iSid = mData["sid"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:ExchangeSummon(oPlayer, iSid)    
end

function C2GSGetSummonRanse(oPlayer,mData)
    local iSummid = mData.summid
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then
        return 
    end
    local mNet = {}
    mNet.summid = iSummid
    mNet.color = oSummon.m_oWaiGuan:GetCurColor()
    oPlayer:Send("GS2CSummonRanse",mNet)
end

function C2GSSummonRanse(oPlayer,mData)
    local iSummid = mData.summid
    local iColor = mData.color 
    local iFlag = mData.flag
    waiguan.UnLockSummonColor(oPlayer,iSummid,iColor,iFlag)
end

function C2GSCombineSummonLead(oPlayer, mData)
    local summid1 = mData["summid1"]
    local summid2 = mData["summid2"]
    local oSummonMgr = global.oSummonMgr
    oSummonMgr:SummonCombine(oPlayer, summid1, summid2, 0, true)
end

function C2GSSummonBindSKill(oPlayer, mData)
    local iSummid = mData.summid
    local iFlag = mData.flag
    local iSkill = mData.skid
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummid)
    if not oSummon then return end
    
    if iFlag == 1 then
        global.oSummonMgr:BindSkill(oPlayer, oSummon, iSkill)    
    else
        global.oSummonMgr:UnBindSkill(oPlayer, oSummon, iSkill)
    end
end

function C2GSExtendSummonSize(oPlayer, mData)
    local iFlag = mData.flag
    global.oSummonMgr:ExtendSummonSize(oPlayer, iFlag)
end

function C2GSExtendSummonCkSize(oPlayer, mData)
    global.oSummonMgr:ExtendSummonCkSize(oPlayer)
end

function C2GSShenShouExchange(oPlayer, mData)
    local iTargetSid = mData.targetsid
    local iSummid1 = mData.summid1
    local iSummid2 = mData.summid2
    local iFlag = mData.flag
    global.oSummonMgr:ShenShouExchange(oPlayer, iTargetSid, iSummid1, iSummid2, iFlag)
end


function C2GSEquipSummon(oPlayer, mData)
    local iSummon, iEquip = mData.summid, mData.equipid
    global.oSummonMgr:EquipSummon(oPlayer, iSummon, iEquip)
end

function C2GSAddCkSummon(oPlayer, mData)
    global.oSummonMgr:AddCkSummon(oPlayer, mData.summid)
end

function C2GSChangeCkSummon(oPlayer, mData)
    global.oSummonMgr:ChangeCkSummon(oPlayer, mData.summid)
end

function C2GSSummonAdvance(oPlayer, mData)
    global.oSummonMgr:SummonAdvance(oPlayer, mData.summid, mData.flag)
end




