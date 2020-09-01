local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"

local summondefines = import(service_path("summon.summondefines"))
local loadsummon = import(service_path("summon.loadsummon"))
local gamedefines = import(lualib_path("public.gamedefines")) 
local analylog = import(lualib_path("public.analylog"))

function NewSummonMgr()
    local o = CSummonMgr:New()
    return o
end

CSummonMgr = {}
CSummonMgr.__index = CSummonMgr
inherit(CSummonMgr, logic_base_cls())

function CSummonMgr:New()
    local o = super(CSummonMgr).New(self)
    return o
end

function CSummonMgr:GetSummonInfo(iSid)
    local mData = res["daobiao"]["summon"]["info"][iSid]
    assert(mData, string.format("summonmgr not find info err: %d", iSid))
    return mData
end

function CSummonMgr:ValidWashSummon(oPlayer, oSummon)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if summondefines.IsImmortalBB(oSummon:Type()) then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1002))
        return false
    end
    if oPlayer.m_oSummonCtrl:GetFightSummon() == oSummon then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1013))
        return false
    end
    -- if oSummon:Type() ~= summondefines.TYPE_WILD and oSummon:Grade() >= 10 then
    --     oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1003))
    --     return false
    -- end
    -- if oPlayer.m_oThisTemp:Query("washsummon") then
    --     oNotifyMgr:Notify(oPlayer:GetPid(),"两次操作之间必须间隔1秒")
    --     return false
    -- end
    return true
end

function CSummonMgr:WashSummon(oPlayer, summid, iFlag)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end

    if not self:ValidWashSummon(oPlayer, oSummon) then return end

    local iCarryGrade = oSummon:CarryGrade()
    local mData = res["daobiao"]["summon"]["washcost"][iCarryGrade]
    if not mData then
        record.warning("not find summon carrygrade %s", iCarryGrade)
        oPlayer:NotifyMessage("该宠物不能洗练")
        return
    end
    assert(mData, string.format("wash summon not find info lv: %d", iCarryGrade))
    local cnt = mData["cnt"]
    if not cnt then return end

    local iResume = math.max(cnt, 1)
    local mLogCost = {}
    if iFlag and iFlag > 0 then
        local sReason = "快捷洗宠"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        mNeedCost["item"][summondefines.ITEM_WASH] = iResume
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end

        if mTrueCost["goldcoin"] then
            mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mLogCost[iSid] = iUseAmount
        end
    else
        local iHasAmount = oPlayer:GetItemAmount(summondefines.ITEM_WASH)
        if iHasAmount < iResume then
            local oItem = global.oItemLoader:GetItem(summondefines.ITEM_WASH)
            oPlayer:NotifyMessage(self:GetText(1001, {item=oItem:TipsName()}))
            return
        end
        oPlayer:RemoveItemAmount(summondefines.ITEM_WASH, iResume, "洗宠")
        mLogCost[summondefines.ITEM_WASH] = iResume
    end
    
    local oNewSummon
    local iWashCnt = oSummon:GetWashCnt()
    if mData["wash_cnt"] > 0 and iWashCnt >= mData["wash_cnt"] then
        iWashCnt = iWashCnt - mData["wash_cnt"]
        oNewSummon = loadsummon.CreateSepWashSummon(oSummon:TypeID())
    end

    local iWashCnt = formula_string(mData["add_cnt"], {}) + iWashCnt
    if not oNewSummon then
        oNewSummon = loadsummon.CreateSummon(oSummon:TypeID(), 0)    
    end

    oNewSummon:GenerateTalent()
    oNewSummon:SetWashCnt(iWashCnt)
    local lTraceNo = oSummon:GetData("traceno")
    oNewSummon:SetData("traceno",lTraceNo)
    local name = oSummon:GetData("name")
    if name then
        oNewSummon:SetData("name",name)
    end

    local oRide = oPlayer.m_oRideCtrl:GetRide(oSummon:GetBindRide())
    if oRide then
        oNewSummon:BindRide(oRide:RideID())
        oRide:ControlEffect(oNewSummon)
    end
    for _,oEquip in pairs(oSummon:GetEquips()) do
        local oNewEquip = global.oItemLoader:LoadItem(oEquip:SID(), oEquip:Save())
        oNewSummon:Equip(oNewEquip)
    end

    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon, "洗宠", {newid=oNewSummon.m_iID})
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon, "wash_summon", {cancel_ui=true})
    oPlayer.m_oSummonCtrl:FireSummonWash(oNewSummon, oSummon)
    if iWashCnt >= mData["wash_cnt"] then
        oPlayer:Send("GS2CSummonWashTips", {summid=oNewSummon.m_iID})
    end

    local mLog = oNewSummon:LogData(oPlayer)
    record.user("summon", "wash_summon", mLog)

    analylog.LogSystemInfo(oPlayer, "summon_wash", nil, mLogCost)
    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "wash_summon", {cnt=iResume})
end

function CSummonMgr:AddSkill(oSummon, skid)
    if oSummon:GetSKill(skid) then return end
        
    local iSize = oSummon:GetSKillCnt()
    if iSize < 4 then
        local mRatio = {[0]=100, [1]=20, [2]=10, [3]=3}
        if math.random(1, 100) <= mRatio[iSize] then
            oSummon:AddSkill(skid)
            return
        end
    end
    
    local oldsk = self:RandomStickSKill(skid, oSummon)
    if oldsk then
        local oOldSkill, iIdx = oSummon:RemoveSkill(oldsk)
        oSummon:AddSkill(skid, oOldSkill:Level(), iIdx)
        return oOldSkill
    else
        oSummon:AddSkill(skid)
    end
end

function CSummonMgr:RandomStickSKill(skid, oSummon)
    -- {5116, 5117} · 学习了亡魂，学习还阳，会有80%的概率打掉亡魂，相反
    local lSkillIds = {}
    local lSkills = oSummon:GetSkillObjList()
    for _, oSkill in pairs(lSkills) do
        if oSkill:IsBind() then goto cotinue end
        
        if table_in_list({5116, 5117}, skid) and table_in_list({5116, 5117}, oSkill:SkID()) then
            if math.random(100) <= 80 then
                return oSkill:SkID()
            end
        end
        table.insert(lSkillIds, oSkill:SkID())
        ::cotinue::
    end
    if #lSkillIds <= 0 then return end

    return extend.Random.random_choice(lSkillIds)
end

-- 要购买的书 sid
function CSummonMgr:FastStickSkill(oPlayer, iSummid, iBookSid)
    local iHasBook = oPlayer:GetItemAmount(iBookSid)
    local sReason = "宠物快捷打书"
    local mCost = {}
    if not self:_ValidLearnNewSkill(oPlayer, iSummid, iBookSid) then
        return
    end
    local iSkid = self:_GetLearnSkillID(oPlayer, iSummid, iBookSid)
    if iSkid == 0 then return end
    if  iHasBook < 1 then
        --快捷打书先判断金币，金币不足时再用元宝补齐
        local mNeedCost = {
            item = { [iBookSid] = 1 }
        }
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        if mTrueCost["gold"] then
            mCost[gamedefines.MONEY_TYPE.GOLD] = mTrueCost["gold"]
        end
    else
        oPlayer:RemoveItemAmount(iBookSid, 1, sReason, {cancle_tip = true})
        mCost[iBookSid] = 1
    end

    self:_LearnNewSkill(oPlayer, iSummid, iSkid, mCost)
end

function CSummonMgr:StickSkill(oPlayer, iSummid, itemid)
    local oItem = oPlayer:HasItem(itemid)
    if not oItem or oItem:GetAmount() < 1 then return end
    local iSid = oItem:SID()
    if not self:_ValidLearnNewSkill(oPlayer, iSummid, iSid) then
        return
    end
    local iSkid = self:_GetLearnSkillID(oPlayer, iSummid, iSid)
    -- 如果 iSkid == 0 ，则说明不可以学习
    if iSkid == 0 then return end
    oPlayer:RemoveItemAmount(iSid, 1, "宠物技能打书", {cancel_tip=true})
    local mCost = { [iSid] = 1}
    self:_LearnNewSkill(oPlayer, iSummid, iSkid, mCost)
end

-- iSid 技能书的 iSid
function CSummonMgr:_ValidLearnNewSkill(oPlayer, iSummid, iSid)
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummid)
    if not oSummon then return false end

    local oItem = global.oItemLoader:GetItem(iSid)
    if oItem:SID() == summondefines.ITEM_BOOK_QIANLI then
        local lLack = oSummon:GetLackingSkill()
        if not lLack or not next(lLack) then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1004, {summon=oSummon:Name(), item=oItem:TipsName()}))
            return false
        end
    elseif oSummon:GetSKill(oItem:GetSummonSkill()) then
        local oSkill = oSummon:GetSKill(oItem:GetSummonSkill())
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1005, {summon=oSummon:Name(), skname=oSkill:Name(), item=oItem:TipsName()}))
        return false
    end
    return true
end

-- 宠物 iSummid 技能书 iSid， 返回学习的技能 iskid
function CSummonMgr:_GetLearnSkillID(oPlayer, iSummid, iSid)
    local iSkid = 0
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummid)
    local oItem = global.oItemLoader:GetItem(iSid)

    if oItem:SID() == summondefines.ITEM_BOOK_QIANLI then
        local lLack = oSummon:GetLackingSkill()
        if not lLack or not next(lLack) then
            return 0
        else
            iSkid = extend.Random.random_choice(lLack)
        end
    elseif not oSummon:GetSKill(oItem:GetSummonSkill()) then
        iSkid = oItem:GetSummonSkill()
    end
    return iSkid
end

function CSummonMgr:_LearnNewSkill(oPlayer, iSummid, iSkid, mCost)
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummid)
    local oOldSkill = self:AddSkill(oSummon, iSkid)
    local oNewSkill = oSummon:GetSKill(iSkid)
    if not oSummon:IsBind() then
        oSummon:Bind(oPlayer:GetPid())
    end
    local mLog = oSummon:LogData(oPlayer)
    mLog["lose_sk"] = 0
    mLog["learn_sk"] = iSkid
    mLog["cost"] = mCost
    if not oOldSkill then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1006, {summon=oSummon:Name(), skname=oNewSkill:Name()}))
    else
        mLog["lose_sk"] = oOldSkill:SkID()
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1007, {summon=oSummon:Name(), skname=oNewSkill:Name(), oskname=oOldSkill:Name()}))
    end
    record.user("summon", "stick_skill", mLog)

    oPlayer.m_oSummonCtrl:FireSummonStickSkill(oSummon, oNewSkill, oOldSkill)

    analylog.LogSystemInfo(oPlayer, "summon_sk_learn", nil, mCost)
end

function CSummonMgr:SkillLevelUp(oPlayer, summid, skid)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
    if not oSummon then return end
        
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local skobj = oSummon:GetSKill(skid)
    if not skobj then return end
        
    if not skobj:CanUpLevel() then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1008, {skname=skobj:Name()}))
        return
    end
    local needgrade = skobj:LearnNeedGrade()
    if oSummon:Grade() < needgrade then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1009, {skname=skobj:Name(), level=needgrade}))
        return
    end

    local amount = skobj:LearnNeedCost()
    if oPlayer:GetItemAmount(summondefines.ITEM_SKILL_STONE) < amount then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1010, {skname=skobj:Name(), amount=amount}))
        return
    end
    
    oPlayer:RemoveItemAmount(summondefines.ITEM_SKILL_STONE, amount, "宠物技能升级")
    local mLog = oSummon:LogData(oPlayer)
    local ratio = skobj:LearnRatio()
    local bSucc = false
    if math.random(1, 100) <= ratio then
        skobj:SkillUnEffect(oSummon)
        skobj:LevelUp()
        global.oScoreCache:Dirty(oPlayer:GetPid(), "summonctrl")
        global.oScoreCache:SummonDirty(oSummon:ID())
        skobj:SkillEffect(oSummon)
        oSummon:PropChange("skill", "score", "rank","summon_score")
        oSummon:RefreshOwnerScore()
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1011, {skname=skobj:Name()}))
        mLog["success"] = 1
        bSucc = true
    else
        mLog["success"] = 0
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1012, {skname=skobj:Name()}))
    end
    oPlayer.m_oSummonCtrl:FireSummonSkillLevelUp(oSummon, bSucc)
    mLog["now_lv"] = skobj:Level()
    mLog["skid"] = skid
    mLog["cost_item"] = summondefines.ITEM_SKILL_STONE
    mLog["cost_cnt"] = amount
    record.user("summon", "skill_level_up", mLog)

    analylog.LogSystemInfo(oPlayer, "summon_sk_upgrade", nil, {[summondefines.ITEM_SKILL_STONE]=amount})
end

function CSummonMgr:SummonXiyouSID(oSummon1, oSummon2)
    local sid1 = oSummon1:TypeID()
    local sid2 = oSummon2:TypeID()
    local iTarSid
    local mInfoList = res["daobiao"]["summon"]["xiyou"]
    for _,mInfo in ipairs(mInfoList) do
        if (mInfo["sid1"] == sid1 and mInfo["sid2"] == sid2) or
            (mInfo["sid1"] == sid2 and mInfo["sid2"] == sid1) then
            iTarSid = mInfo["sid3"]
        end
    end
    if not iTarSid then return end

    local mSummon = self:GetSummonInfo(iTarSid)
    if not mSummon then return end

    local iRatio = 0
    local iCarryLv = mSummon["carry"] or 0
    local mData = self:GetSummonConfig()
    for _,m in pairs(mData["combine_xy_ratio"] or {}) do
        if iCarryLv < m.grade then break end

        iRatio = m.ratio
    end
    if iRatio >= math.random(1, 100) then
        return iTarSid
    end
    return nil
end

function CSummonMgr:SummonXiyouSID_new(oSummon1, oSummon2)
    local sid1 = oSummon1:TypeID()
    local sid2 = oSummon2:TypeID()
    local mInfoList = res["daobiao"]["summon"]["xiyou"]
    for _,mInfo in ipairs(mInfoList) do
        if (mInfo["sid1"] == sid1 and mInfo["sid2"] == sid2) or
            (mInfo["sid1"] == sid2 and mInfo["sid2"] == sid1) then
            return mInfo["sid3"]
        end
    end
end

function CSummonMgr:GetSummonXiyouInfo(iSid)
    local mInfoList = res["daobiao"]["summon"]["xiyou"]
    for _,mInfo in ipairs(mInfoList) do
        if mInfo["sid3"] == iSid then
            return mInfo
        end
    end
    return nil
end

function CSummonMgr:RandomCombineSID_new(oSummon1, oSummon2)
    local iResultSID = self:SummonXiyouSID_new(oSummon1, oSummon2)
    if iResultSID then return iResultSID end

    local lXiYou, lNormal = {}, {}
    if oSummon1:Type() == summondefines.TYPE_XIYOUBB then
        table.insert(lXiYou, oSummon1:TypeID())
    else
        table.insert(lNormal, oSummon1:TypeID())
    end
    if oSummon2:Type() == summondefines.TYPE_XIYOUBB then
        table.insert(lXiYou, oSummon2:TypeID())
    else
        table.insert(lNormal, oSummon2:TypeID())
    end

    if #lXiYou == 1 then
        local iRatio = self:GetSummonConfig()["combine_xy_ratio_new"]
        if math.random(100) <= iRatio then
            iResultSID = lXiYou[1]
        else
            iResultSID = lNormal[1]
        end     
    else
        local iMaxCarrySid, iMinCarrySid, iMaxCarry, iMixCarry
        if oSummon1:CarryGrade() >= oSummon2:CarryGrade() then
            iMaxCarrySid, iMinCarrySid = oSummon1:TypeID(), oSummon2:TypeID()             
            iMaxCarry, iMixCarry = oSummon1:CarryGrade(), oSummon2:CarryGrade()
        else
            iMaxCarrySid, iMinCarrySid = oSummon2:TypeID(), oSummon1:TypeID()           
            iMaxCarry, iMixCarry = oSummon2:CarryGrade(), oSummon1:CarryGrade()
        end
        local sFormat = self:GetSummonConfig()["heigh_ratio"]
        local iRatio = formula_string(sFormat, {maxlv=iMaxCarry,minlv=iMixCarry})
        if math.random(100) <= iRatio then
            iResultSID = iMaxCarrySid
        else
            iResultSID = iMinCarrySid
        end
    end
    return iResultSID
end

-- 特殊处理的合宠逻辑
function CSummonMgr:LeadSummonCombine(oPlayer, oSummon1, oSummon2)
    if (oSummon1:TypeID() == 2029 and oSummon2:TypeID() == 2030)
        or (oSummon1:TypeID() == 2030 and oSummon2:TypeID() == 2029) then

        local iTaskid = 30062
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
        if not oTask then
            return nil
        end
        local oNewSummon = loadsummon.CreateFixedPropSummon(1003, 3)
        return oNewSummon
    end
    return nil
end

function CSummonMgr:GetCombineCostAmount_new(oSummon1, oSummon2)
    local iMaxCarry = math.max(oSummon1:CarryGrade(), oSummon2:CarryGrade())
    local mCost = res["daobiao"]["summon"]["washcost"][iMaxCarry]
    if not mCost then
        record.warning("combine not find summon carrygrade %s", iMaxCarry)
        -- oPlayer:NotifyMessage(self:GetText(2031))
        return
    end
    if oSummon1:Type() == summondefines.TYPE_XIYOUBB or 
        oSummon2:Type() == summondefines.TYPE_XIYOUBB or 
        self:SummonXiyouSID_new(oSummon1, oSummon2) then
        return mCost["xy_combine_cost"]
    end
    return mCost["combine_cost"]
end

function CSummonMgr:GetCombineCostAmount(oSummon1, oSummon2)
    local iMaxCarry = math.max(oSummon1:CarryGrade(), oSummon2:CarryGrade())
    local mCost = res["daobiao"]["summon"]["washcost"][iMaxCarry]
    if not mCost then
        record.warning("combine not find summon carrygrade %s", iMaxCarry)
        -- oPlayer:NotifyMessage(self:GetText(2031))
        return
    end
    return mCost["combine_cost"]
end

-- TODO 新改的合成
function CSummonMgr:SummonCombine(oPlayer, summid1, summid2, iFlag, bLead)
    local oSummon1 = oPlayer.m_oSummonCtrl:GetSummon(summid1)
    local oSummon2 = oPlayer.m_oSummonCtrl:GetSummon(summid2)
    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    if not oSummon1 or not oSummon2 then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1014))
        return
    end
    local oFight = oPlayer.m_oSummonCtrl:GetFightSummon()
    if oFight == oSummon1 or oFight == oSummon2 then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1023))
        return
    end
    if not summondefines.IsBB(oSummon1:Type()) or not summondefines.IsBB(oSummon1:Type()) then
        oPlayer:NotifyMessage(self:GetText(2027))
        return
    end
    if oSummon1:IsBindRide() or oSummon2:IsBindRide() then
        return
    end

    -- 引导合成
    local oNewSummon, iPoint
    if bLead then
        oNewSummon, iPoint = self:LeadSummonCombine(oPlayer, oSummon1, oSummon2)
    end

    if not oNewSummon then
        if oSummon1:IsWild() or oSummon2:IsWild() then
            oPlayer:NotifyMessage(self:GetText(2012))
            return 
        end
        local iLimitGrade = oPlayer:GetGrade() + 5
        local iResultSID = self:RandomCombineSID_new(oSummon1, oSummon2)
        oNewSummon, iPoint = loadsummon.CreateCombineSummon(iResultSID, oSummon1, oSummon2, iLimitGrade)
    end

    local iCostAmount = self:GetCombineCostAmount_new(oSummon1, oSummon2)
    if iFlag > 0 then
        local sReason = "快捷合宠"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        mNeedCost["item"][summondefines.ITEM_COMBINE] = iCostAmount
        local bSucc, mTrueCost =  global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
    else
        if iCostAmount > oPlayer:GetItemAmount(summondefines.ITEM_COMBINE) then
            local sTipsName = global.oItemLoader:GetItemTipsNameBySid(summondefines.ITEM_COMBINE)
            oPlayer:NotifyMessage(self:GetText(2032, {item=sTipsName}))
            return
        end
        oPlayer:RemoveItemAmount(summondefines.ITEM_COMBINE, iCostAmount, "合宠")
    end

    local mNet = {
        id1=oSummon1.m_iID,
        id2=oSummon2.m_iID,
        resultid=oNewSummon.m_iID,
    }
    iPoint = iPoint + self:GetCombinePoint()
    local mLog = oNewSummon:LogData(oPlayer)
    mLog["summon1"] = oSummon1:LogData()
    mLog["summon2"] = oSummon2:LogData()
    mLog["book_id"] = 0
    mLog["book_cnt"] = 0
    mLog["store_id"] = 0
    mLog["store_cnt"] = 0
    record.user("summon", "combine_summon", mLog)
    analylog.LogSystemInfo(oPlayer, "summon_combine")

    if oSummon1:IsBind() or oSummon2:IsBind() then
        oNewSummon:Bind(oPlayer:GetPid())
    end

    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon1, "合宠")
    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon2, "合宠",{newid=oNewSummon.m_iID})
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon)
    oPlayer:RewardSummonPoint(iPoint, "合成宠物")
    oPlayer:Send("GS2CSummonCombineResult", mNet)
    oPlayer.m_oSummonCtrl:FireSummonCombine(oNewSummon, {oSummon1, oSummon2})
    oPlayer:MarkGrow(18)
end

function CSummonMgr:GetCombinePoint()
    local mRatio = {[3]= 40, [5]=30, [1]=30}
    return table_choose_key(mRatio)
end

function CSummonMgr:GetTotalExp(oSummon)
    local mUpGrade = res["daobiao"]["upgrade"]
    local iExp = oSummon:Exp()
    for i=1,oSummon:GetGrade() do
        iExp = iExp + mUpGrade[i]["summon_exp"] 
    end
    return iExp
end

function CSummonMgr:CalRestoreExp(oSummon1, oSummon2)
    local mData = self:GetSummonConfig()
    local iRatio = mData["re_combine_exp"]
    local iFixedExp = math.floor((self:GetTotalExp(oSummon1) + self:GetTotalExp(oSummon2)) * iRatio / 100)
    return iFixedExp
end

function CSummonMgr:UseSummonExpBook(oPlayer, oSummon, iSid, cnt)
    if not iSid or iSid <= 0 then
        iSid = 10033    
    end
    if not table_in_list(summondefines.ITEM_SUMMON_EXP, iSid) then return end
    
    local oItem = global.oItemLoader:GetItem(iSid)
    if oPlayer:GetItemAmount(iSid) < cnt then
        oPlayer:NotifyMessage(self:GetText(1001, {item=oItem:TipsName()}))
        return
    end
    
    local iCalExp = oItem:CalItemFormula(oPlayer, {})
    local iAmount, iOldExp, iOldLevel = 0, oSummon:Exp(), oSummon:Grade()
    for i=1,cnt do
        if oSummon:Grade() >= oPlayer:GetGrade() + 5 then
            oPlayer:NotifyMessage(self:GetText(1015, {summon=oSummon:Name()}))
            break
        end
        iAmount = iAmount + 1
        oPlayer:RemoveItemAmount(iSid, 1, "宠物升级")
        oSummon:RewardExp(iCalExp, "summonexpbook")
    end
    oPlayer.m_oSummonCtrl:FireUseSummonExpBook(oSummon, iAmount)

    if iAmount > 0 then
        if not oSummon:IsBind() then
            oSummon:Bind(oPlayer:GetPid())
        end
        
        local mLog = oSummon:LogData(oPlayer)
        mLog["old_exp"] = iOldExp
        mLog["old_level"] = iOldLevel
        mLog["cost_item"] = iSid
        mLog["cost_cnt"] = iAmount
        record.user("summon", "use_exp_book", mLog)
        analylog.LogSystemInfo(oPlayer, "summon_upgrade", nil, {[iSid]=iAmount})
    end
end

function CSummonMgr:AptitudeScheduleAdd(oSummon, sAptitude)
    local iSchedule = 0
    if summondefines.NotNormalBB(oSummon:Type()) then
        iSchedule = math.floor((27 - (oSummon:MaxAptitude(sAptitude) - oSummon:CurAptitude(sAptitude)) * 100 / oSummon:BaseAptitude(sAptitude)) / 27 * 100)
    else
        iSchedule = math.floor((23 - (oSummon:MaxAptitude(sAptitude) - oSummon:CurAptitude(sAptitude)) * 100 / oSummon:BaseAptitude(sAptitude)) / 23 * 100)
    end
    iSchedule = math.max(0, iSchedule)
    local mDaobiao = res["daobiao"]["summon"]["aptitudepellet"]
    for _, mData in ipairs(mDaobiao) do
        if iSchedule >= mData["schedule"][1] and iSchedule <= mData["schedule"][2] then
            return table.unpack(mData["add"])
        end
    end
    return 0, 0
end

function CSummonMgr:UseAptitudePellet(oPlayer, oSummon, aptitude, iFlag)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local sAptitude = summondefines.APTITUDES[aptitude]
    if not sAptitude or oSummon:CurAptitude(sAptitude) >= oSummon:MaxAptitude(sAptitude) then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1016))
        return
    end
    local iAddMin, iAddMax = self:AptitudeScheduleAdd(oSummon, sAptitude)
    if iAddMin == 0 and iAddMax == 0 then return end

    local iShape = 10034
    local iAmount = oPlayer:GetItemAmount(iShape)
    local sReason
    local mCost = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷增加宠物资质"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        mNeedCost["item"][iShape] = 1
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mCost[iSid] = iUseAmount
        end
        if mTrueCost["goldcoin"] then
            mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
    else
        sReason = "增加宠物资质"
        if iAmount < 1 then
            local oItem = global.oItemLoader:GetItem(iShape)
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1001, {item=oItem:TipsName()}))
            return
        end
        oPlayer:RemoveItemAmount(iShape, 1, sReason)
        mCost[iShape]  = 1
    end

    
    local mLog = oSummon:LogData(oPlayer)
    mLog["old_val"] = oSummon:CurAptitude(sAptitude)
    local iAdd = math.random(iAddMin, iAddMax)
    oSummon:AddCurAptitude(sAptitude, iAdd)
    if not oSummon:IsBind() then
        oSummon:Bind(oPlayer:GetPid())
    end
    oPlayer.m_oSummonCtrl:FireCultivateSummonAptitude(oSummon)
    oSummon:Setup()
    oSummon:FullState()
    oSummon:Refresh() 

    mLog["cost"] = mCost
    mLog["attr"] = sAptitude
    mLog["now_val"] = oSummon:CurAptitude(sAptitude)
    mLog["add_val"] = iAdd
    record.user("summon", "use_aptitude_pellet", mLog)

    analylog.LogSystemInfo(oPlayer, "summon_aptitude", nil, {[10034]=1})
end

function CSummonMgr:UseGrowPellet(oPlayer, oSummon)
    local iMaxUse = self:GetMaxUseGrow()
    local iUseCnt = oSummon:GetData("cnt_usegrow", 0)
    if iUseCnt >= iMaxUse then
        oPlayer:NotifyMessage(self:GetText(1017))        
        return
    end
    local iAmount = oPlayer:GetItemAmount(10035)
    if iAmount < 1 then
        local oItem = global.oItemLoader:GetItem(10035)
        oPlayer:NotifyMessage(self:GetText(1001, {item=oItem:TipsName()}))
        return
    end
    local iGrow = self:CalGrow()
    local iOldGrow = oSummon:Grow()
    oPlayer:RemoveItemAmount(10035, 1)
    oSummon:SetData("cnt_usegrow", iUseCnt + 1)
    if not oSummon:IsBind() then
        oSummon:Bind(oPlayer:GetPid())
    end
    self:AddSummonGrow(oSummon, iGrow)

    local mLog = oSummon:LogData(oPlayer)
    mLog["old_grow"] = iOldGrow
    mLog["now_grow"] = oSummon:Grow()
    record.user("summon", "use_grow_pellet", mLog)
end

function CSummonMgr:AddSummonGrow(oSummon, iGrow)
    oSummon:AddGrow(iGrow)
    oSummon:OnAddGrow()
    oSummon:Setup()
    oSummon:FullState()
    oSummon:Refresh() 
end

function CSummonMgr:GetMaxUseGrow()
    return self:GetSummonConfig()["use_grow_cnt"]
end

function CSummonMgr:CalGrow()
    local lConfig = self:GetSummonConfig()["add_grow"]
    local mRaito = {}
    for _,m in pairs(lConfig) do
        mRaito[m["val"]] = m["weight"]
    end
    return table_choose_key(mRaito)
end

function CSummonMgr:UsePointPellet(oPlayer, oSummon, attr)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if oSummon:IsWild() then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1018))
        return
    end
    if oSummon:Grade() < 10 then
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1019))
        return
    end
    if attr == 6 then
        self:UseWashAllPoint(oPlayer, oSummon)
        return
    else
        local sAttr = summondefines.ATTRS[attr]
        if not sAttr or oSummon:Attribute(sAttr) <= 10 + oSummon:Grade() then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1020))
            return
        end
        local iAmount = oPlayer:GetItemAmount(10036)
        if iAmount < 1 then
            local oItem = global.oItemLoader:GetItem(10036)
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1001, {item=oItem:TipsName()}))
            return
        end

        local mLog = oSummon:LogData(oPlayer)
        mLog["old_val"] = oSummon:Attribute(sAttr)

        oPlayer:RemoveItemAmount(10036, 1, "宠物洗点")
        local iWash = math.max(0, oSummon:Attribute(sAttr) - (10 + oSummon:Grade()))
        iWash = math.min(2, iWash)
        if iWash > 0 then
            oSummon:AddAttribute(sAttr, -iWash)
            oSummon:AddPoint(iWash)
            oSummon:SetAutoSwitch(0)
            oSummon:Setup()
            oSummon:Refresh()
        end

        mLog["cost_item"] = 10036
        mLog["cost_cnt"] = 1
        mLog["attr"] = sAttr
        mLog["now_val"] = oSummon:Attribute(sAttr)
        mLog["wash_val"] = iWash
        record.user("summon", "wash_attr_point", mLog)

        analylog.LogSystemInfo(oPlayer, "reset_summon_point", nil, {[10036]=1})
    end
end

function CSummonMgr:UseWashAllPoint(oPlayer, oSummon)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr

    local mLog = oSummon:LogData(oPlayer)
    local lWashAttr = {}
    mLog["free"] = 0
    mLog["cost_item"] = 10037
    mLog["cost_cnt"] = 0

    if oSummon:GetData("freepoint", 0) ~= 1 then
        local mInitAddAttr = oSummon:GetInitAttribute()
        local bWashed = false
        mLog["free"] = 1
        for _, sAttr in ipairs(summondefines.ATTRS) do
            local iInitAdd = 0
            if mInitAddAttr and mInitAddAttr[sAttr] then
                iInitAdd = math.max(0, mInitAddAttr[sAttr])
            end
            local iWash = math.max(0, oSummon:Attribute(sAttr) - (10 + oSummon:Grade() + iInitAdd) )
            if iWash > 0 then
                bWashed = true
                break
            end
        end
        if not bWashed then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1020))
            return
        end
        oSummon:SetData("freepoint", 1)
        oSummon:PropChange("freepoint")
        for _, sAttr in ipairs(summondefines.ATTRS) do
            local iInitAdd = 0
            if mInitAddAttr and mInitAddAttr[sAttr] then
                iInitAdd = math.max(0, mInitAddAttr[sAttr])
            end
            local iWash = math.max(0, oSummon:Attribute(sAttr) - (10 + oSummon:Grade() + iInitAdd) )
            local iOldVal = oSummon:Attribute(sAttr)
            if iWash > 0 then
                oSummon:AddAttribute(sAttr, -iWash)
                oSummon:AddPoint(iWash)
                oSummon:SetAutoSwitch(0)
                oSummon:Setup()
                oSummon:Refresh()
            end
            table.insert(lWashAttr, {attr=sAttr, old_val=iOldVal, now_val=oSummon:Attribute(sAttr), wash_val=iWash})
        end
    else
        local iAmount = oPlayer:GetItemAmount(10037)
        if iAmount < 1 then
            local oItem = global.oItemLoader:GetItem(10037)
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1001, {item=oItem:TipsName()}))
            return
        end
        local bWashed = false
        for _, sAttr in ipairs(summondefines.ATTRS) do
            if oSummon:Attribute(sAttr) - (10 + oSummon:Grade()) > 0 then
                bWashed = true
                break
            end
        end
        if not bWashed then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSummonText(1020))
            return
        else
            oPlayer:RemoveItemAmount(10037, 1, "宠物洗点")
            mLog["cost_cnt"] = mLog["cost_cnt"] + 1
            for _, sAttr in ipairs(summondefines.ATTRS) do
                local iWash = math.max(0, oSummon:Attribute(sAttr) - (10 + oSummon:Grade()) )
                local iOldVal = oSummon:Attribute(sAttr)
                if iWash > 0 then
                    oSummon:AddAttribute(sAttr, -iWash)
                    oSummon:AddPoint(iWash)
                    oSummon:SetAutoSwitch(0)
                    oSummon:Setup()
                    oSummon:Refresh()
                end
                table.insert(lWashAttr, {attr=sAttr, old_val=iOldVal, now_val=oSummon:Attribute(sAttr), wash_val=iWash})
            end
        end
    end
    mLog["wash_attr"] = lWashAttr
    record.user("summon", "wash_all_point", mLog)

    analylog.LogSystemInfo(oPlayer, "reset_summon_all_point", nil, {[mLog["cost_item"]]=mLog["cost_cnt"]})
end

function CSummonMgr:UseLifePellet(oPlayer, oSummon, iItem, iCnt)
    if summondefines.IsImmortalBB(oSummon:Type()) then
        oPlayer:NotifyMessage(self:GetText(1021))
        return
    end

    local iOldLife = oSummon:Life()
    local mLog = oSummon:LogData(oPlayer)
    mLog["old_life"] = iOldLife
    mLog["cost_item"] = 10038
    mLog["cost_cnt"] = 0

    local isUse = false
    if iItem <= 0 or iItem == 10038 then
        if oPlayer:GetItemAmount(10038) < iCnt then
            local oItem = global.oItemLoader:GetItem(10038)
            oPlayer:NotifyMessage(self:GetText(1001, {item=oItem:TipsName()}))
            return
        end

        for i=1, iCnt do
            if oSummon:Life() >= 60000 then
                break
            end
            isUse  = true
            mLog["cost_cnt"] = mLog["cost_cnt"] + 1
            oPlayer:RemoveItemAmount(10038, 1, "使用寿命丹")
            oSummon:AddLife(500)
        end
    else
        local lItemObj = oPlayer.m_oItemCtrl:GetShapeItem(iItem)
        local oBaseItem = global.oItemLoader:GetItem(iItem)
        if not oBaseItem:CanUse2SummonLife() then
            record.warning("cant use for summon life")
            return
        end
        if #lItemObj <= 0 then
            oPlayer:NotifyMessage(self:GetText(1001, {item=oBaseItem:TipsName()}))
            return
        end
        local oItem = lItemObj[1]
        iCnt = math.min(oItem:GetAmount(), iCnt)

        mLog["cost_item"] = oBaseItem:SID()
        for i=1, iCnt do
            if oSummon:Life() >= 60000 then break end

            isUse  = true
            mLog["cost_cnt"] = mLog["cost_cnt"] + 1

            local iLife = oItem:CalSummonLife(oPlayer, oSummon)
            oPlayer:RemoveOneItemAmount(oItem, 1, "使用物品增加寿命")
            oSummon:AddLife(iLife)
        end
    end

    if not isUse then
        oPlayer:NotifyMessage(self:GetText(1022))
        return
    end
    if not oSummon:IsBind() then
        oSummon:Bind(oPlayer:GetPid())
    end
    mLog["now_life"] = oSummon:Life()
    record.user("summon", "use_life_book", mLog)

    analylog.LogSystemInfo(oPlayer, "summon_life", nil, {[mLog["cost_item"]]=mLog["cost_cnt"]})
end

function CSummonMgr:ExchangeSummon(oPlayer, iSid)
    local mData = self:GetSummonInfo(iSid)
    local mCost = mData["item"]
    local iItem, iCnt = mCost["id"], mCost["cnt"] or 0
    if iCnt <= 0 then return end

    if mData["carry"] > oPlayer:GetGrade() then
        oPlayer:NotifyMessage(self:GetText(1051))
        return
    end

    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() <= 0 then
        oPlayer:NotifyMessage(self:GetText(1052))
        return
    end

    local iAmount = oPlayer:GetItemAmount(iItem)
    if iAmount < iCnt then
        local oItem = global.oItemLoader:GetItem(iItem)
        oPlayer:NotifyMessage(self:GetText(1001, {item=oItem:TipsName()}))
        return
    end

    oPlayer:RemoveItemAmount(iItem, iCnt, "exchange_summon")
    local oNewSummon = loadsummon.CreateSummon(iSid, 0)
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon, "exchange_summon")
    oPlayer:NotifyMessage(self:GetText(1050))

    local mLog = oNewSummon:LogData(oPlayer)
    mLog["cost"] = iItem
    mLog["cnt"] = iCnt
    record.user("summon", "exchange_summon", mLog)
end

function CSummonMgr:SetFight(oPlayer, oSummon, iFight, bNotity)
    if not oSummon then return end

    if iFight == 1 then
        if oSummon:Grade() > oPlayer:GetGrade() + 10 then
            if bNotity then
                oPlayer:NotifyMessage(self:GetText(1054, {summon=oSummon:Name()}))
            end
            return
        end
        if oSummon:CarryGrade() > oPlayer:GetGrade() then
            if bNotity then
                oPlayer:NotifyMessage(self:GetText(1055, {level=oSummon:CarryGrade()}))
            end
            return
        end
        oPlayer.m_oSummonCtrl:SetFight(oSummon:ID())
    else
        if oSummon ~= oPlayer.m_oSummonCtrl:GetFightSummon() then
            return
        end
        oPlayer.m_oSummonCtrl:UnFight()
    end
end

function CSummonMgr:BindSkill(oPlayer, oSummon, iSkill)
    if not oSummon then return end

    local oSkill = oSummon:GetSKill(iSkill)
    if not oSkill then return end

    if oSummon:HasBindSkill() then
        oPlayer:NotifyMessage(self:GetText(2010))
        return
    end

    local mCost = self:GetSummonConfig()["band_skill_cost"]
    local iSid, iAmount = mCost["sid"], mCost["num"]
    if oPlayer:GetItemAmount(iSid) < iAmount then
        oPlayer:NotifyMessage(self:GetText(2011))
        return 
    end 
    oPlayer:RemoveItemAmount(iSid, iAmount, "宠物绑定技能") 
    oSkill:SetBind(1)
    if not oSummon:IsBind() then
        oSummon:Bind(oPlayer:GetPid())
    end
    oSummon:PropChange("skill")
end

function CSummonMgr:UnBindSkill(oPlayer, oSummon, iSkill)
    if not oSummon then return end

    local oSkill = oSummon:GetSKill(iSkill)
    if not oSkill then return end

    if not oSkill:IsBind() then return end

    oSkill:SetBind(0)
    oSummon:PropChange("skill") 
end

function CSummonMgr:GetExtendCost(sKey, iCnt)
    local vCost
    for k,v in pairs(self:GetSummonConfig()[sKey]) do
        vCost = v
        if iCnt <= k then break end
    end 
    return vCost
end

function CSummonMgr:ExtendSummonSize(oPlayer, iFlag)
    if not oPlayer.m_oSummonCtrl:CanAddExtendSize() then
        oPlayer:NotifyMessage(self:GetText(2014))
        return
    end

    local iCnt = oPlayer.m_oSummonCtrl:GetExtendSize() 
    local iCost = self:GetExtendCost("extend_cost", iCnt+1)
    local iSid = 11186
    local iHas = oPlayer:GetItemAmount(iSid)
    local sReason
    local mCostLog = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷开宠物携带格子"
        local iGoldCoinToItem = 0
        local mLackItem = {} 
        local mTrueCostItem = {}
        if iHas < iCost then
            mLackItem[iSid] = {amount = iCost - iHas, gamedefines.STORE_TYPE.NPCSTORE}
            if iHas > 0 then
                mTrueCostItem[iSid] = iHas
            end
        else
            mTrueCostItem[iSid] = iCost
        end
        if next(mLackItem) then
            local bExist, iNeed = global.oFastBuyMgr:GetFastBuyCost(oPlayer, mLackItem, sReason)
            if not bExist then return end
            iGoldCoinToItem = iNeed
        end
        if iGoldCoinToItem > 0 then
            if not oPlayer:ValidGoldCoin(iGoldCoinToItem) then return end
            oPlayer:ResumeGoldCoin(iGoldCoinToItem, sReason)
            mCostLog[gamedefines.MONEY_TYPE.GOLDCOIN] = iGoldCoinToItem
        end
        for iSid, iAmount in pairs(mTrueCostItem) do
            oPlayer:RemoveItemAmount(iSid, iAmount , sReason)
            mCostLog[iSid] = iAmount
        end
    else
        if oPlayer:GetItemAmount(iSid) < iCost then 
            local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iSid)
            oPlayer:NotifyMessage(self:GetText(1001, {item=sTipsName}))     
            return 
        end
        oPlayer:RemoveItemAmount(iSid, iCost, "开宠物携带格子")     
        mCostLog[iSid] = iCost   
    end
    oPlayer.m_oSummonCtrl:AddExtendSize(1)
    oPlayer:Send("GS2CSummonExtendSize", {extsize=(iCnt + 1)})

    local mLog = oPlayer:LogData()
    mLog["count"] = iCnt + 1
    mLog["cost"] = mCostLog
    record.user("summon", "extend_size", mLog)
end

function CSummonMgr:ExtendSummonCkSize(oPlayer)
    if not oPlayer.m_oSummCkCtrl:CanExtendCkSize() then
        oPlayer:NotifyMessage(self:GetText(2015))
        return
    end

    local iCnt = oPlayer.m_oSummCkCtrl:GetExtendCkSize()

    local mCost = self:GetExtendCost("extend_ck_cost", iCnt+1)
    if not oPlayer:ValidMoneyByType(mCost["id"], mCost["count"]) then return end

    oPlayer:ResumeMoneyByType(mCost["id"], mCost["count"], "开宠物仓库")        
    oPlayer.m_oSummCkCtrl:AddExtendCkSize(1)
    oPlayer:Send("GS2CSummonCkExtendSize", {extcksize=(iCnt + 1)})

    local mLog = oPlayer:LogData()
    mLog["count"] = iCnt + 1
    mLog["goldcoin"] = mCost["count"]
    record.user("summon", "extend_ck_size", mLog)
end

function CSummonMgr:ShenShouExchange(oPlayer, iExchange, iSummon1, iSummon2, iFlag)
    if not iSummon1 or iSummon1 <= 0 then
        self:ItemExchange(oPlayer, iExchange, iFlag)
    else
        self:SummonExchange(oPlayer, iExchange, iSummon1, iSummon2, iFlag)
    end
end

-- 只有三眼灵猴和雪灵兽允许快捷购买
function CSummonMgr:FastItemExchange(oPlayer, iExchange)
    local mData = res["daobiao"]["summon"]["shenshouexchange"][iExchange]
    if not mData then return end
    local iTargetSid = mData.sid
    if iTargetSid ~= 5001 and iTargetSid ~= 5004 then
        record.warning("shenshou fastitemexchange error shenshousid %d",iTargetSid)
        return
    end
    local lCostItem = mData["cost"]
    if #lCostItem <= 0 then return end
    local sReason = "快捷神兽兑换"
    local mNeedCost = {}
    mNeedCost["item"] = {}
    for _, mData in pairs(lCostItem) do
        mNeedCost["item"][mData.sid] = mData.num
    end
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
    if not bSucc then return end
    local mLogCost = {}
    for iSid, iUseAmount in pairs(mTrueCost["item"]) do
        mLogCost[iSid] = iUseAmount
    end
    if mTrueCost["goldcoin"] then
        mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
    end
    local mLog = oPlayer:LogData()
    mLog["sid"] = iTargetSid
    mLog["sid1"] = 0
    mLog["sid2"] = 0
    mLog["cost_item"] = mLogCost
    record.user("summon","ss_exchange", mLog)

    local oNewSummon
    if mData["fixid"] and mData["fixid"] > 0 then
        oNewSummon = loadsummon.CreateFixedPropSummon(iTargetSid, mData["fixid"])
    else
        oNewSummon = loadsummon.CreateSummon(iTargetSid)
    end
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon, sReason)
    self:SendChuanWen(oPlayer, mData["chuanwen"])

end

function CSummonMgr:ItemExchange(oPlayer, iExchange, iFlag)
    local mData = res["daobiao"]["summon"]["shenshouexchange"][iExchange]

    if not mData then return end

    local iTargetSid = mData["sid"]

    if iFlag and iFlag > 0 then
        if iTargetSid == 5001 or iTargetSid == 5004 then
            self:FastItemExchange(oPlayer, iExchange)
            return
        else
            return
        end
    end

    local lCost = mData["cost"]
    if #lCost <= 0 then return end

    for _,m in pairs(lCost) do
        if oPlayer:GetItemAmount(m["sid"]) < m["num"] then
            local sTipsName = global.oItemLoader:GetItemTipsNameBySid(m["sid"])
            oPlayer:NotifyMessage(self:GetText(1001), {item = sTipsName})
            return
        end
    end
    local iSid1, iSid2 = mData['sid1'], mData['sid2']
    if iSid1 > 0 or iSid2 > 0 then return end

    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() <= 0 then
        oPlayer:NotifyMessage(self:GetText(2016))
        return
    end
    local oNewSummon
    if mData["fixid"] and mData["fixid"] > 0 then
        oNewSummon = loadsummon.CreateFixedPropSummon(iTargetSid, mData["fixid"])
    else
        oNewSummon = loadsummon.CreateSummon(iTargetSid)
    end
    for _,m in pairs(lCost) do
        oPlayer:RemoveItemAmount(m["sid"], m["num"], "神兽兑换")
    end
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon, "神兽兑换")
    self:SendChuanWen(oPlayer, mData["chuanwen"])

    local mLog = oPlayer:LogData()
    mLog["sid"] = iTargetSid
    mLog["sid1"] = 0
    mLog["sid2"] = 0
    mLog["cost_item"] = lCost
    record.user("summon", "ss_exchange", mLog)
end

function CSummonMgr:SummonExchange(oPlayer, iExchange, iSummon1, iSummon2, iFlag)
    local mData = res["daobiao"]["summon"]["shenshouexchange"][iExchange]
    if not mData then return end

    local iSid1, iSid2 = mData['sid1'], mData['sid2']
    local oFight = oPlayer.m_oSummonCtrl:GetFightSummon()
    local oSummon1 = oPlayer.m_oSummonCtrl:GetSummon(iSummon1)
    local oSummon2 = oPlayer.m_oSummonCtrl:GetSummon(iSummon2)
    if not oSummon1 or not oSummon2 then
        record.warning("CSummonMgr:SummonExchange not find summon %s %s %s", oPlayer:GetPid(), iSummon1, iSummon2)
        return
    end
    if oSummon1 == oFight or oSummon2 == oFight then return end
    if not (oSummon1:TypeID() == iSid1 and oSummon2:TypeID() == iSid2) and 
        not (oSummon1:TypeID() == iSid2 and oSummon2:TypeID() == iSid1) then
        return
    end

    local iReAmount = 0
    local mConfig = self:GetAdvanceConfig(oSummon1:Type(), oSummon1:AdvanceLevel())
    if mConfig then
        iReAmount = mConfig["combine_restore"] or 0 
    end
    mConfig = self:GetAdvanceConfig(oSummon2:Type(), oSummon2:AdvanceLevel())
    if mConfig then
        iReAmount = iReAmount + mConfig["combine_restore"] or 0 
    end
    if iReAmount > 0 then
        local mGive = {[summondefines.ITEM_SHENSHOU_STONE]=iReAmount}
        if not oPlayer:ValidGive(mGive) then return end
    end

    local iTargetSid = mData["sid"]
    local mCost = {}
    local sReason = "神兽兑换"
    for _,m in pairs(mData["cost"]) do
        mCost[m["sid"]] = m["num"]
    end
    local mCostLog = {}
    if iFlag and iFlag > 0 then
        local mNeedCost = {}
        mNeedCost["item"] = mCost
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end

        if mTrueCost["goldcoin"] then
            mCostLog[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mCostLog[iSid] = iUseAmount
        end
    else
        for iSid, iAmount in pairs(mCost) do
            if oPlayer:GetItemAmount(iSid) < iAmount then
                local sTipsName = global.oItemLoader:GetItemTipsNameBySid(iSid)
                oPlayer:NotifyMessage(self:GetText(1001, {item = sTipsName}))
                return
            end
        end
        for iSid, iAmount in pairs(mCost) do
            oPlayer:RemoveItemAmount(iSid, iAmount, sReason)
        end
        mCostLog = mCost
    end

    local oNewSummon
    if mData["fixid"] and mData["fixid"] > 0 then
        oNewSummon = loadsummon.CreateFixedPropSummon(iTargetSid, mData["fixid"])
    else
        oNewSummon = loadsummon.CreateSummon(iTargetSid)
    end
    if iReAmount > 0 then
        oPlayer:GiveItem({[summondefines.ITEM_SHENSHOU_STONE]=iReAmount}, "神兽兑换") 
    end

    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon1, "神兽兑换")
    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon2, "神兽兑换", {newid=oNewSummon.m_iID})
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon)
    self:SendChuanWen(oPlayer, mData["chuanwen"])

    local mLog = oPlayer:LogData()
    mLog["sid"] = iTargetSid
    mLog["sid1"] = iSid1
    mLog["sid2"] = iSid2
    mLog["cost_item"] = mCostLog
    record.user("summon", "ss_exchange", mLog)
end

function CSummonMgr:SendChuanWen(oPlayer, iChuanWen, oSummon)
    local mChuanWen = res["daobiao"]["chuanwen"][iChuanWen]
    if not mChuanWen then return end
    
    local sContend = mChuanWen.content
    local mReplace = {role = oPlayer:GetName()}
    if oSummon then
        mReplace.summon = oSummon:Name()
    end
    local sMsg = global.oToolMgr:FormatColorString(mChuanWen.content, mReplace)
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanWen.horse_race)
end

function CSummonMgr:EquipSummon(oPlayer, iSummon, iEquip)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummon)
    if not oSummon then return end

    local oEquip = oPlayer:HasItem(iEquip)
    if not oEquip or oEquip:ItemType() ~= "summonequip" then return end

    local oNewEquip = global.oItemLoader:LoadItem(oEquip:SID(), oEquip:Save())
    oPlayer:RemoveOneItemAmount(oEquip, 1, "装备宠物", {cancel_chat=true, cancel_tip=true})
    oSummon:Equip(oNewEquip)
    oPlayer:NotifyMessage(self:GetText(2030, {item=oNewEquip:TipsName()}))

    local mLog = oSummon:LogData(oPlayer)
    mLog["equip"] = oEquip:SID()
    record.user("summon", "equip_summon", mLog)
end

function CSummonMgr:AddCkSummon(oPlayer, iSummon)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummon)
    local oFight = oPlayer.m_oSummonCtrl:GetFightSummon()
    if not oSummon or oSummon == oFight then return end

    if oPlayer.m_oSummCkCtrl:EmptyCkSpaceCnt() <= 0 then
        oPlayer:NotifyMessage(self:GetText(2017))
        return
    end

    if oPlayer.m_oThisTemp:Query("add_temp_summon") then
        oPlayer:NotifyMessage("请稍等.....")
        return
    end
    oPlayer.m_oThisTemp:Set("add_temp_summon", 1, 1)
    local oRide = oPlayer.m_oRideCtrl:GetRide(oSummon:GetBindRide())
    if oRide then
        local iPos = oRide:GetSummonPos(oSummon)
        if iPos then
            oRide:UnControlSummon(iPos)
            oRide:GS2CUpdateRide(oPlayer)
            oPlayer:NotifyMessage(self:GetText(1056, {summon=oSummon:Name()}))
        end
    end

    local oNewSummon = loadsummon.LoadSummon(oSummon:TypeID(), oSummon:Save())
    oPlayer.m_oSummonCtrl:RemoveSummon(oSummon, "存仓库", {cancel_record=true})
    oPlayer.m_oSummCkCtrl:AddCkSummon(oNewSummon)   

    local mLog = oSummon:LogData(oPlayer)
    record.user("summon", "add_ck_summon", mLog)
end

function CSummonMgr:ChangeCkSummon(oPlayer, iSummon)
    local oSummon = oPlayer.m_oSummCkCtrl:GetCkSummon(iSummon)
    if not oSummon then return end

    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() <= 0 then
        oPlayer:NotifyMessage(self:GetText(2016))
        return
    end

    local oNewSummon = loadsummon.LoadSummon(oSummon:TypeID(), oSummon:Save())
    oPlayer.m_oSummCkCtrl:RemoveCkSummon(oSummon)
    oPlayer.m_oSummonCtrl:AddSummon(oNewSummon, "仓库提取", {cancel_ui=true, cancel_record=true})   

    local mLog = oSummon:LogData(oPlayer)
    record.user("summon", "change_ck_summon", mLog)
end

function CSummonMgr:SummonAdvance(oPlayer, iSummon, iFlag)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummon)
    if not oSummon then return end

    if not summondefines.IsShenShouBB(oSummon:Type()) and not summondefines.IsXYZhenShouBB(oSummon:Type()) then
        oPlayer:NotifyMessage(self:GetText(2034))
        return
    end

    local iAdvance = oSummon:AdvanceLevel()
    local mConfig = self:GetAdvanceConfig(oSummon:Type(), iAdvance+1)
    if not mConfig then
        oPlayer:NotifyMessage(self:GetText(2035))
        return
    end
    if oSummon:Grade() < mConfig["mix_lv"] then
        oPlayer:NotifyMessage(self:GetText(2036, {summon=oSummon:Name(),level=mConfig["mix_lv"]}))
        return
    end
    local iAmount = mConfig["cost_amount"]
    assert(iAmount>0, string.format("summon advance cost error"))

    local sReason
    local iCostSid
    if summondefines.IsShenShouBB(oSummon:Type()) then
        sReason = "神兽进阶"
        iCostSid = summondefines.ITEM_SHENSHOU_STONE
    elseif summondefines.IsXYZhenShouBB(oSummon:Type()) then
        sReason = "稀有珍兽进阶"
        iCostSid = summondefines.ITEM_XYZHENSHOU_STONE
    else
        return
    end
    -- local mLogCost = {}
    if iFlag and iFlag > 0 then
        local mNeedCost = {}
        mNeedCost["item"] = {[iCostSid] = iAmount}
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end

        -- if mTrueCost["goldcoin"] then
        --     mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        -- end
        -- for iSid, iUseAmount in pairs(mTrueCost["item"]) do
        --     mLogCost[iSid] = iUseAmount
        -- end
    else
        if oPlayer:GetItemAmount(iCostSid) < iAmount then
            oPlayer:NotifyMessage("物品不足")
            return
        end
        oPlayer:RemoveItemAmount(iCostSid, iAmount, sReason)
        -- mLogCost = {[summondefines.ITEM_SHENSHOU_STONE] = iAmount}
    end

    oSummon:SummonAdvance(iAdvance+1)
    oPlayer:NotifyMessage(self:GetText(2039, {summon=oSummon:Name(), amount=summondefines.CH_NUM_MAP[iAdvance+1]}))

    local mLog = oSummon:LogData(oPlayer)
    mLog["old_adv_lv"] = iAdvance
    mLog["now_adv_lv"] = oSummon:AdvanceLevel()
    record.user("summon", "summon_advance", mLog)
end

function CSummonMgr:GetAdvanceConfig(iType, iAdvance)
    local mData = res["daobiao"]["summon"]["shenshouadvance"]
    if iType == summondefines.TYPE_XYHOLY then
        mData = res["daobiao"]["summon"]["xyshenshouadvance"]
    elseif iType == summondefines.TYPE_XYZHENSHOU then
        mData = res['daobiao']["summon"]["xyzhenshouadvance"]
    end
    return mData[iAdvance]
end

function CSummonMgr:GetFightSummonCount(iGrade)
    local lConfig = self:GetSummonConfig()['fight_count']
    local iCnt = 1
    for _,v in pairs(lConfig) do
        if iGrade > v.grade then
            iCnt = v.num
        end
    end
    return iCnt
end

function CSummonMgr:GetText(iText, m)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetSummonText(iText, m)
end

function CSummonMgr:GetSummonConfig()
    return res["daobiao"]["summon"]["config"][1]
end
