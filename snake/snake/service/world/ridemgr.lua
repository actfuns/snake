local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record" 

local rideobj = import(service_path("ride.rideobj"))
local skillobj = import(service_path("ride.skillbase"))
local ridedefines = import(service_path("ride.ridedefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))


function NewRideMgr(...)
    return CRideMgr:New(...)
end

CRideMgr = {}
CRideMgr.__index = CRideMgr
inherit(CRideMgr, logic_base_cls())

function CRideMgr:New()
    local o = super(CRideMgr).New(self)
    return o
end

function CRideMgr:GetRideConfigDataById(iRide)
    local mData = res["daobiao"]["ride"]["rideinfo"][iRide]
    assert(mData,string.format("undefind rideinfo err: %d", iRide))
    return mData
end

function CRideMgr:GetRideAllAttrEffect()
    local mData = res["daobiao"]["ride"]["rideinfo"]
    local mAttr = {}
    for _,info in pairs(mData) do
        local mEffect = info["attr_effect"] or {}
        for _, sEffect in ipairs(mEffect) do
            local sApply,_ = string.match(sEffect,"(.+)=(.+)")
            mAttr[sApply] = true
        end
    end
    return mAttr
end

function CRideMgr:GetOtherConfigByKey(sKey)
    local mData = res["daobiao"]["ride"]["other"][1]
    return mData[sKey]
end

function CRideMgr:GetAllSkillConfig()
    return res["daobiao"]["ride"]["skill"]
end

function CRideMgr:GetSkillConfig(iSk)
    local mData = res["daobiao"]["ride"]["skill"][iSk]
    return mData
end

function CRideMgr:CreateNewRide(iRide, ...)
    local oRide = rideobj.NewRide(iRide)
    oRide:Create(...)
    return oRide
end

function CRideMgr:LoadRide(iRide, iPid, m)
    local oRide = rideobj.NewRide(iRide)
    oRide:Load(m)
    oRide:SetPid(iPid)
    return oRide
end

function CRideMgr:CreatNewSkill(iSkill, ...)
    local oSkill = skillobj.NewSkill(iSkill)
    return oSkill
end

function CRideMgr:LoadSkill(iSkill, m)
    local oSkill = skillobj.NewSkill(iSkill)
    oSkill:Load(m)
    return oSkill
end

function CRideMgr:ActivateRide(oPlayer, iRide)
    local mData = self:GetRideConfigDataById(iRide)
    if not mData then return end

    local oRideCtrl = oPlayer.m_oRideCtrl
    if oRideCtrl:GetRide(iRide) then return end

    if mData["player_level"] > oPlayer:GetGrade() then
        oPlayer:NotifyMessage(self:GetText(1002))
        return
    end  
    if mData["ride_level"] > oRideCtrl:GetGrade() then
        oPlayer:NotifyMessage(self:GetText(1003))
        return
    end
    local lItem = mData["activate_item"]
    for _, mItem in pairs(lItem) do
        if oPlayer:GetItemAmount(mItem["itemid"]) < mItem["cnt"] then
            local oItem = global.oItemLoader:GetItem(mItem["itemid"])
            oPlayer:NotifyMessage(self:GetText(1004, {item=oItem:TipsName()}))
            return
        end 
    end

    local mCostLog = {}
    for _, mItem in pairs(lItem) do
        mCostLog[mItem["itemid"]] = mItem["cnt"]
        oPlayer:RemoveItemAmount(mItem["itemid"], mItem["cnt"], "坐骑激活")
    end

    local mLog = oPlayer:LogData()
    mLog["ride_id"] = iRide
    mLog["cost"] = mCostLog
    record.user("ride", "activate_ride", mLog)

    local oRide = self:CreateNewRide(iRide)
    oRideCtrl:AddRide(oRide)

    analylog.LogSystemInfo(oPlayer, "activate_ride", iRide, mCostLog)
end

function CRideMgr:UseRide(oPlayer, iRide, iFlag)
    if iFlag == 0 then
        oPlayer.m_oRideCtrl:UnUseRide() 
    else
        oPlayer.m_oRideCtrl:UseRide(iRide)
    end
end

function CRideMgr:UpGradeRide(oPlayer, iFlag)
    if not global.oToolMgr:IsSysOpen("RIDE_UPGRADE", oPlayer) then return end
    
    if oPlayer.m_oRideCtrl:IsMaxLevel() then
        oPlayer:NotifyMessage(self:GetText(1005))
        return
    end

    local iUpGradeExp = oPlayer.m_oRideCtrl:GetUpGradeExp()
    local iCurExp = oPlayer.m_oRideCtrl:GetExp()
    if iCurExp >= iUpGradeExp then
        oPlayer:NotifyMessage(self:GetText(1029))
        return
    end

    local iSid = self:GetOtherConfigByKey("upgrade_item")
    local iHasCnt = oPlayer:GetItemAmount(iSid)
    if iHasCnt < 1 then
        if iFlag == 1 then
            self:FastUpGradeRide(oPlayer, iSid, iUpGradeExp, iCurExp)
            return
        end
        oPlayer:NotifyMessage(self:GetText(1006))
        return
    end
    
    local oItem = global.oItemLoader:GetItem(iSid)   
    local iRealExp = oItem:CalItemFormula(oPlayer, {})
    assert(iRealExp > 0, string.format("ride exp book error"))
    local iCostCnt = math.ceil((iUpGradeExp - iCurExp) / iRealExp)
    iCostCnt = math.min(iCostCnt, iHasCnt)
    oPlayer:RemoveItemAmount(iSid, iCostCnt, "坐骑升级")
    oPlayer.m_oRideCtrl:AddExp(iRealExp*iCostCnt, "经验丹")

    local iOldLevel = oPlayer.m_oRideCtrl:GetGrade()    
    local mCost = {sid=iSid, cnt=iCostCnt}
    local mLog = oPlayer:LogData()
    mLog["cost"] = mCost
    mLog["ridelv"] = iOldLevel
    record.user("ride", "upgrade_ride", mLog)
    analylog.LogSystemInfo(oPlayer, "upgrade_ride", nil, {[iSid]=iCostCnt})
end

function CRideMgr:FastUpGradeRide(oPlayer, iSid, iUpGradeExp, iCurExp)
    local iAmount = 1
    local mNeedCost = { item = { [iSid] = iAmount } }
    local sReason = "快捷坐骑升级"
    local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
    if not bSucc then return end

    local oItem = global.oItemLoader:GetItem(iSid)   
    local iRealExp = oItem:CalItemFormula(oPlayer, {})
    assert(iRealExp > 0, string.format("ride exp book error"))
    oPlayer.m_oRideCtrl:AddExp(iRealExp*iAmount, "经验丹快捷购买")

    local iOldLevel = oPlayer.m_oRideCtrl:GetGrade()    
    local mLog = oPlayer:LogData()
    mLog["cost"] = mTrueCost
    mLog["ridelv"] = iOldLevel
    record.user("ride", "upgrade_ride", mLog)
    analylog.LogSystemInfo(oPlayer, "upgrade_ride", nil, {[iSid]=iAmount})
end

function CRideMgr:BreakRideGrade(oPlayer, iFlag)
    if not global.oToolMgr:IsSysOpen("RIDE_UPGRADE", oPlayer) then return end
    
    if oPlayer.m_oRideCtrl:IsMaxLevel() then
        oPlayer:NotifyMessage(self:GetText(1005))
        return
    end

    local mData = res["daobiao"]["ride"]["upgrade"]
    local iGrade = oPlayer.m_oRideCtrl:GetGrade() + 1
    local mGrade = mData[iGrade]
    if oPlayer.m_oRideCtrl:GetExp() < mGrade["ride_exp"] then
        return
    end

    local lCost = mGrade["break_cost"]
    -- assert(#lCost > 0, string.format("ride break upgrade cost error"))
    local sReason
    local mCostLog = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷坐骑突破"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        for _, mItem in pairs(lCost) do
            mNeedCost["item"][mItem.itemid] = mItem.cnt
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mCostLog[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mCostLog[iSid] = iUseAmount
        end
    else
        for _,mItem in pairs(lCost) do
            local iSid = mItem["itemid"]
            local iAmount = mItem["cnt"]
            if oPlayer:GetItemAmount(iSid) < iAmount then
                local oItem = global.oItemLoader:GetItem(iSid)
                oPlayer:NotifyMessage(self:GetText(1004, {item=oItem:TipsName()}))
                return
            end 
        end
        for _, mItem in pairs(lCost) do
            oPlayer:RemoveItemAmount(mItem["itemid"], mItem["cnt"], "坐骑突破")
            mCostLog[mItem["itemid"]] = mItem["cnt"]
        end
    end
    oPlayer.m_oRideCtrl:CheckUpGrade(iGrade)
    oPlayer.m_oRideCtrl:GS2CPlayerRideInfo("grade", "exp", "point", "attrs", "score")

    local mLog = oPlayer:LogData()
    mLog["cost"] = mCostLog
    mLog["ridelv"] = iGrade
    record.user("ride", "ride_break", mLog)

    analylog.LogSystemInfo(oPlayer, "break_ride", nil, mCostLog)
end

function CRideMgr:CheckActivateRide(oPlayer, iRide)
    local oRideCtrl = oPlayer.m_oRideCtrl
    local mData = self:GetRideConfigDataById(iRide)
    if not mData then return false end

    if mData["player_level"] > oPlayer:GetGrade() then
        oPlayer:NotifyMessage(self:GetText(1002))
        return false
    end  
    if mData["ride_level"] > oRideCtrl:GetGrade() then
        oPlayer:NotifyMessage(self:GetText(1003))
        return false
    end
    return true
end

function CRideMgr:BuyRideUseTime(oPlayer, iSell)
    local mData = res["daobiao"]["ride"]["buytime"][iSell]
    assert(mData,string.format("undefind buytime err: %d", iSell))

    local oRideCtrl = oPlayer.m_oRideCtrl
    local iRide = mData["ride_id"]
    local oRide = oRideCtrl:GetRide(iRide)
    if oRide and oRide:IsForever() then
        oPlayer:NotifyMessage(self:GetText(1008))
        return
    end

    if not oRide and not self:CheckActivateRide(oPlayer, iRide) then
        return
    end

    local lItem = mData["cost_item"]
    for _, mItem in pairs(lItem) do
        if oPlayer:GetItemAmount(mItem["itemid"]) < mItem["cnt"] then
            local oItem = global.oItemLoader:GetItem(mItem["itemid"])
            oPlayer:NotifyMessage(self:GetText(1004, {item=oItem:TipsName()}))
            return
        end
    end
    for _, mCost in pairs(mData["cost_money"]) do
        if not oPlayer:ValidMoneyByType(mCost["type"], mCost["cnt"]) then
            return
        end
    end    

    local mCostLog = {}
    for _, mItem in pairs(lItem) do
        mCostLog[mItem["itemid"]] = mItem["cnt"]
        oPlayer:RemoveItemAmount(mItem["itemid"], mItem["cnt"], "坐骑续期")
    end
    for _, mCost in pairs(mData["cost_money"]) do
        mCostLog[mCost["type"]] = mCost["cnt"]
        oPlayer:ResumeMoneyByType(mCost["type"], mCost["cnt"], "坐骑续期")
    end    

    local sMsg
    local iValDay = mData["valid_day"]
    if not oRide then
        oRide = self:CreateNewRide(iRide, {valid_day=iValDay})
        oRideCtrl:AddRide(oRide)
        if iValDay <= 0 then
            sMsg = self:GetText(1028, {ride_name=oRide:GetName()})
        else
            sMsg = self:GetText(1027, {ride_name=oRide:GetName(), count=iValDay})
        end
    else
        oRide:AddExpireTime(iValDay)
        oRide:GS2CUpdateRide(oPlayer)
        if iValDay <= 0 then
            sMsg = self:GetText(1022, {ride_name=oRide:GetName()})
        else
            sMsg = self:GetText(1020, {ride_name=oRide:GetName(), count=iValDay})
        end
    end
    oPlayer:NotifyMessage(sMsg)
    local mLog = oPlayer:LogData()
    mLog["ride_id"] = oRide:RideID()
    mLog["cost"] = mCostLog
    record.user("ride", "buy_time_ride", mLog)

    analylog.LogSystemInfo(oPlayer, "activate_ride", iRide, mCostLog)
end

function CRideMgr:RandomRideSkill(oPlayer, iFlag)
    local oRideCtrl = oPlayer.m_oRideCtrl
    if oRideCtrl:GetSkillPoint() <= 0 then
        oPlayer:NotifyMessage(self:GetText(1009))
        return
    end

    local mCost = {}
    local sReason
    if iFlag and iFlag > 0 then
        if oRideCtrl:HasChooseSkills() then
            local lCost = self:GetOtherConfigByKey("random_cost")
            sReason = "快捷坐骑领悟技能"
            local mNeedCost = {}
            mNeedCost["item"] = {}
            for _, mItem in pairs(lCost) do
                mNeedCost["item"][mItem.sid] = mItem.cnt
            end
            local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
            if not bSucc then return end
            if mTrueCost["goldcoin"] then
                mCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
            end
            for iSid, iUseAmount in pairs(mTrueCost["item"]) do
                mCost[iSid] = iUseAmount
            end
        end
    else
        if oRideCtrl:HasChooseSkills() then
            local lCost = self:GetOtherConfigByKey("random_cost")
            for _,v in pairs(lCost) do
                if oPlayer:GetItemAmount(v["sid"]) < v["cnt"] then
                    oPlayer:NotifyMessage(self:GetText(1010))
                    return
                end
            end
            for _,v in pairs(lCost) do
                oPlayer:RemoveItemAmount(v["sid"], v["cnt"], "坐骑领悟技能")
                mCost[v["sid"]] = v["cnt"]
            end
        end
    end

    self:RandomLearnSkill(oPlayer)
    oRideCtrl:GS2CPlayerRideInfo("choose_skills")
    local mLog = oPlayer:LogData()
    mLog["goldcoin"] = mCost
    record.user("ride", "random_skill", mLog)

    analylog.LogSystemInfo(oPlayer, "random_sk_ride", nil, mCost)
end

function CRideMgr:RandomLearnSkill(oPlayer)
    local mCanLearnSkill = oPlayer.m_oRideCtrl:GetCanLearnSkills()
    assert(table_count(mCanLearnSkill) > 0, string.format("ride RandomLearnSkill error"))
    local mChooseSkill = table_copy(mCanLearnSkill)

    local lChooseSk = {}
    for i = 1, 2 do
        local iChooseSk = table_choose_key(mChooseSkill)
        table.insert(lChooseSk, iChooseSk)
        mChooseSkill[iChooseSk] = nil
    end
    oPlayer.m_oRideCtrl:SetChooseSkills(lChooseSk)
end

function CRideMgr:LearnRideSkill(oPlayer, iSkill)
    local oRideCtrl = oPlayer.m_oRideCtrl
    if oRideCtrl:GetSkillPoint() <= 0 then
        oPlayer:NotifyMessage(self:GetText(1009))
        return
    end
    local lChooseSk = oRideCtrl:GetChooseSkills()
    if not table_in_list(lChooseSk, iSkill) then
        oPlayer:NotifyMessage(self:GetText(1012))
        return
    end
    local oSkill = oRideCtrl:GetSkill(iSkill)
    if oSkill then
        if oSkill:IsMaxLevel() then
            oPlayer:NotifyMessage(self:GetText(1014))
            return
        end
        oRideCtrl:AddSkillPoint(-1)
        oSkill:SkillUnEffect(oRideCtrl)
        oSkill:AddLevel(1)
        oSkill:SkillEffect(oRideCtrl)
        oRideCtrl:RefreshScore()
    else
        oSkill = self:CreatNewSkill(iSkill)
        local bRet = oRideCtrl:AddSkill(oSkill)
        if not bRet then
            oPlayer:NotifyMessage(self:GetText(1015)) 
            return
        end
        oRideCtrl:AddSkillPoint(-1)
        oRideCtrl:RefreshScore()
    end
    oRideCtrl:ClearCanLearnSkill()
    oRideCtrl:SetChooseSkills({})
    oRideCtrl:GS2CPlayerRideInfo("point", "choose_skills", "skills", "score")
end

function CRideMgr:CalForgetCost(mCostItem, sKey, iAmount)
    local lCostItem = self:GetOtherConfigByKey(sKey)
    assert(#lCostItem > 0, string.format("not find %s", sKey))
    for _,v in pairs(lCostItem) do
        local iSid = v["sid"]
        local iCnt = v["cnt"] * iAmount
        mCostItem[iSid] = (mCostItem[iSid] or 0) + iCnt
    end
    return mCostItem
end

-- iFastBuyFlag 用来区分快捷购买
function CRideMgr:ForgetRideSkill(oPlayer, iSkill, iFlag)
    local oRideCtrl = oPlayer.m_oRideCtrl 
    if oRideCtrl:HasChooseSkills() then
        oPlayer:NotifyMessage(self:GetText(1016))
        return
    end

    local oSkill = oRideCtrl:GetSkill(iSkill)
    if not oSkill then
        oPlayer:NotifyMessage(self:GetText(1017))
        return
    end

    local mCostItem, iTotalCnt = {}, 0
    local lExtraSkill, iExtraCnt = {}, 0
    local iBaseIndex = oRideCtrl:GetBaseIndex(iSkill)
    if iBaseIndex then
        local lSKillId = oRideCtrl:GetAdvanceSkillByIndex(iBaseIndex)
        for _,iSk in pairs(lSKillId) do
            local oSk = oRideCtrl:GetSkill(iSk)
            assert(oSk, string.format("ride forget skill not find skill %s", iSk))
            table.insert(lExtraSkill, iSk)
            iExtraCnt = iExtraCnt + oSk:Level()
        end
        iTotalCnt = iExtraCnt + 1
        self:CalForgetCost(mCostItem, "forget_base_cost", 1)
        self:CalForgetCost(mCostItem, "forget_adv_cost", iExtraCnt)
    else
        iTotalCnt = 1
        self:CalForgetCost(mCostItem, "forget_adv_cost", 1)
    end

    assert(table_count(mCostItem) > 0, string.format("ride forget cost error %s", iSkill))
    local sReason
    local mLogCost = {}
    if iFlag and iFlag > 0 then
        sReason = "快捷坐骑技能遗忘"
        local mNeedCost = {}
        mNeedCost["item"] = {}
        for iSid, iCnt in pairs(mCostItem) do
            mNeedCost["item"][iSid] = iCnt
        end
        local bSucc, mTrueCost = global.oFastBuyMgr:FastBuy(oPlayer, mNeedCost, sReason, {cancel_tip = true})
        if not bSucc then return end
        if mTrueCost["goldcoin"] then
            mLogCost[gamedefines.MONEY_TYPE.GOLDCOIN] = mTrueCost["goldcoin"]
        end
        for iSid, iUseAmount in pairs(mTrueCost["item"]) do
            mLogCost[iSid] = iUseAmount
        end
    else
        for iSid, iCnt in pairs(mCostItem) do
            if oPlayer:GetItemAmount(iSid) < iCnt then
                oPlayer:NotifyMessage(self:GetText(1019, {
                    amount = iCnt,
                    item = global.oItemLoader:GetItem(iSid):TipsName(),    
                }))
                return
            end
        end
        for iSid, iCnt in pairs(mCostItem) do
            oPlayer:RemoveItemAmount(iSid, iCnt, "坐骑技能遗忘")
        end
        mLogCost = mCostItem
    end

    local mLog = oPlayer:LogData()
    mLog["skid"] = iSkill
    mLog["flag"] = lExtraSkill
    mLog["cost"] = mLogCost
    record.user("ride", "reset_skill", mLog)

    for _,iSk in pairs(lExtraSkill) do
        local bRet = oRideCtrl:RemoveSkill(iSk)
        if not bRet then
            oPlayer:NotifyMessage(self:GetText(1018))
            return
        end
    end

    if oSkill:Level() <= 1 then
        local bRet = oRideCtrl:RemoveSkill(iSkill)
        if not bRet then
            oPlayer:NotifyMessage(self:GetText(1018))
            return
        end
        oPlayer:SecondLevelPropChange()
    else
        oSkill:SkillUnEffect(oRideCtrl)
        oSkill:AddLevel(-1)
        oSkill:SkillEffect(oRideCtrl)
    end
    oRideCtrl:AddSkillPoint(iTotalCnt)
    oRideCtrl:GS2CPlayerRideInfo("point", "skills", "score")

    analylog.LogSystemInfo(oPlayer, "forget_sk_ride", nil, mLogCost)
end

function CRideMgr:SetRideFly(oPlayer, iRide, iFly)
    oPlayer.m_oRideCtrl:SetRideFly(iFly)
end


function CRideMgr:CalTotalExp(iGrade, iExp)
    local mData = res["daobiao"]["ride"]["upgrade"]

    local iTotalExp = iExp
    for i=1,iGrade do
        local mGrade = mData[i]
        assert(mGrade, string.format("not find ride upgrade %s", i))
        iTotalExp = iTotalExp + mGrade["ride_exp"]
    end
    return iTotalExp
end

function CRideMgr:CalRideGrade(iExp)
    local mData = res["daobiao"]["ride"]["upgrade"]

    local iGrade = 0
    for i=1, 200 do
        local mGrade = mData[iGrade + 1]
        if iExp < mGrade["ride_exp"] then break end

        iExp = iExp - mGrade["ride_exp"]
        iGrade = iGrade + 1        
    end
    return iGrade, iExp
end

function CRideMgr:CalResetSkillInfo(oPlayer)
    local iOldExp = oPlayer.m_oRideCtrl:GetExp()
    local iOldGrade = oPlayer.m_oRideCtrl:GetGrade()

    local iTotalExp = self:CalTotalExp(iOldGrade, iOldExp)
    local iRatio = self:GetOtherConfigByKey("reset_exp_ratio")
    local iRealExp = math.floor(iTotalExp * iRatio / 100)

    local iGrade, iExp = self:CalRideGrade(iRealExp)
    return iGrade, iExp, iTotalExp-iRealExp
end

function CRideMgr:CheckResetSkill(oPlayer)
    if oPlayer.m_oRideCtrl:GetGrade() <= 0 then
        return false, self:GetText(1024) 
    end
    if oPlayer.m_oRideCtrl:GetSkillCnt() <= 0 then
        return false, self:GetText(1025)
    end
    local iWeekCnt = self:GetOtherConfigByKey("reset_week_cnt")
    if oPlayer.m_oWeekMorning:Query("ride_skill_reset", 0) >= iWeekCnt then
        return false, self:GetText(1026)
    end
    return true
end

function CRideMgr:ResetRideSkill(oPlayer)
    if not self:CheckResetSkill(oPlayer) then return end

    local iOldExp = oPlayer.m_oRideCtrl:GetExp()
    local iOldGrade = oPlayer.m_oRideCtrl:GetGrade()
    local iGrade, iExp = self:CalResetSkillInfo(oPlayer)
    oPlayer.m_oRideCtrl:ResetRideSkill(oPlayer, iGrade, iExp)
    oPlayer.m_oWeekMorning:Add("ride_skill_reset", 1)

    local mLog = oPlayer:LogData()
    mLog["oldlv"] = iOldGrade
    mLog["oldexp"] = iOldExp
    mLog["newlv"] = iGrade
    mLog["newexp"] = iExp
    record.user("ride", "reset_ride", mLog)
    -- self:_TrueResetRideSkill(oPlayer:GetPid(), iGrade, iExp)
end

function CRideMgr:GS2CResetSKillInfo(oPlayer)
    local bRet, sMsg = self:CheckResetSkill(oPlayer)
    if not bRet then
        oPlayer:NotifyMessage(sMsg)
        return 
    end    
    local iGrade, iExp, iCostExp = self:CalResetSkillInfo(oPlayer)
    local mNet = {
        cost_exp = iCostExp,
        grade = iGrade,
        point = iGrade
    }
    oPlayer:Send("GS2CResetSKillInfo", mNet)
end

function CRideMgr:GetText(iText, m)
    return global.oToolMgr:GetSystemText({"ride"}, iText, m)
end

function CRideMgr:WieldWenShi(oPlayer, iRide, iItemId, iPos)
    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if not oRide or oRide:IsExpire() then 
        oPlayer:NotifyMessage(self:GetText(1045))
        return 
    end

    local oItem = oPlayer:HasItem(iItemId)
    if not oItem or oItem:ItemType() ~= "wenshi" then return end

    if oItem:GetLast() <= 0 or not oRide:CanWield(oItem, iPos) then
        oPlayer:NotifyMessage(self:GetText(1031))
        return
    end

    local oOldWenShi = oRide:GetWenShiByPos(iPos)
    if oOldWenShi then
        self:UnWieldWenShi2(oPlayer, oRide, iPos)    
    end

    local oWenShi = global.oItemLoader:LoadItem(oItem:SID(), oItem:Save())
    oPlayer:RemoveOneItemAmount(oItem, 1, "纹饰佩戴", {cancel_chat=true, cancel_tip=true})
    oWenShi:Bind(oPlayer:GetPid())
    oRide:WieldWenShi(oWenShi, iPos)
    oRide:GS2CUpdateRide(oPlayer)
    oPlayer:NotifyMessage(self:GetText(1032))

    local mLog = oPlayer:LogData()
    mLog["ride_id"] = iRide
    mLog["item"] = {sid=oWenShi:SID(), level=oWenShi:GrowLevel()}
    record.user("ride", "wield_wenshi", mLog)
end

function CRideMgr:UnWieldWenShi(oPlayer, iRide, iPos)
    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if not oRide then return end

    local oWenShi = oRide:GetWenShiByPos(iPos)
    if not oWenShi then return end

    local mLogWenShi = {sid=oWenShi:SID(), level=oWenShi:GrowLevel()}
    local bFlag = self:UnWieldWenShi2(oPlayer, oRide, iPos)
    if bFlag then
        oPlayer:NotifyMessage(self:GetText(1033))    
    else
        oPlayer:NotifyMessage(self:GetText(1034))
    end
    oRide:GS2CUpdateRide(oPlayer)

    local mLog = oPlayer:LogData()
    mLog["ride_id"] = iRide
    mLog["item"] = mLogWenShi
    mLog["flag"] = bFlag and 1 or 0
    record.user("ride", "unwield_wenshi", mLog)
end

function CRideMgr:UnWieldWenShi2(oPlayer, oRide, iPos)
    local oWenShi = oRide:GetWenShiByPos(iPos)
    if not oWenShi then return end

    local oNewItem 
    if oWenShi:GetLast() > 0 then
        local sFormat = self:GetOtherConfigByKey("clear_ratio")
        local iRatio = formula_string(sFormat, {max_last=oWenShi:GetMaxLast(), cur_last=oWenShi:GetLast()})    
        if math.random(100) > iRatio then
            oNewItem = global.oItemLoader:LoadItem(oWenShi:SID(), oWenShi:Save())
        end
    end
    oRide:UnWieldWenShi(iPos)
    if oNewItem then
        oPlayer:RewardItem(oNewItem, "纹饰卸载")
        return true
    end
end

function CRideMgr:ControlSummon(oPlayer, iRide, iSummon, iPos)
    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if not oRide or oRide:IsExpire() then
        oPlayer:NotifyMessage(self:GetText(1046))
        return 
    end

    local oSummon = oPlayer.m_oSummonCtrl:GetSummon(iSummon)
    if not oSummon then return end

    local iOldRide = oSummon:GetBindRide()
    local oOldRide = oPlayer.m_oRideCtrl:GetRide(iOldRide)
    if oOldRide then
        local iOldPos = oOldRide:GetSummonPos(oSummon)
        if iOldPos then
            oOldRide:UnControlSummon(iOldPos)
            oOldRide:GS2CUpdateRide(oPlayer)
        end
    end

    oRide:UnControlSummon(iPos)
    oRide:ControlSummon(oSummon, iPos)
    oRide:GS2CUpdateRide(oPlayer)
    oPlayer:NotifyMessage(self:GetText(1035))

    local mLog = oPlayer:LogData()
    mLog["ride_id"] = iRide
    mLog["summon"] = {sid=oSummon:TypeID(), traceno=oSummon:GetData("traceno")}
    mLog["pos"] = iPos
    record.user("ride", "control_summon", mLog)
end

function CRideMgr:UnControlSummon(oPlayer, iRide, iPos)
    local oRide = oPlayer.m_oRideCtrl:GetRide(iRide)
    if not oRide then return end

    oRide:UnControlSummon(iPos)
    oRide:GS2CUpdateRide(oPlayer)
    oPlayer:NotifyMessage(self:GetText(1036))

    local mLog = oPlayer:LogData()
    mLog["ride_id"] = iRide
    mLog["pos"] = iPos
    record.user("ride", "uncontrol_summon", mLog)
end



