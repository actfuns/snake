--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local giftmgr = import(service_path("player.giftmgr"))
local vigormgr = import(service_path("player.vigorctrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local shareobj = import(lualib_path("base.shareobj"))

CPlayerActiveCtrl = {}
CPlayerActiveCtrl.__index = CPlayerActiveCtrl
inherit(CPlayerActiveCtrl, datactrl.CDataCtrl)

function CPlayerActiveCtrl:New(pid)
    local o = super(CPlayerActiveCtrl).New(self, {pid = pid})
    o.m_mNowSceneInfo = nil
    o.m_mNowWarInfo = nil
    o.m_oGiftMgr = giftmgr.NewGiftMgr(pid)
    o.m_oVisualMgr = CPlayerVisualMgr:New(pid)
    o.m_oVigorCtrl = vigormgr.NewVigorCtrl(pid)
    o.m_oSceneShareObj = nil
    return o
end

function CPlayerActiveCtrl:Release()
    self:ClearNowSceneInfo()
    self:ClearNowWarInfo()
    self:ClearSceneShareObj()
    baseobj_safe_release(self.m_oGiftMgr)
    baseobj_safe_release(self.m_oVisualMgr)
    baseobj_safe_release(self.m_oVigorCtrl)
    super(CPlayerActiveCtrl).Release(self)
end

function CPlayerActiveCtrl:Load(mData)
    local mData = mData or {}
    local mRoleInitProp = res["daobiao"]["roleprop"][1]

    self:SetData("scene_info", mData.scene_info)
    self:SetData("hp", mData.hp)
    self:SetData("mp", mData.mp)
    self:SetData("sp", mData.sp)
    self:SetData("gold",mData.gold or 0)
    self:SetData("silver",mData.silver or 0)
    self:SetData("wuxun",mData.wuxun or 0)
    self:SetData("jjcpoint",mData.jjcpoint or 0)
    self:SetData("exp",mData.exp or mRoleInitProp.exp)
    self:SetData("chubeiexp",mData.chubeiexp or 0)
    self:SetData("energy", mData.energy or mRoleInitProp.energy)
    self:SetData("disconnect_time", mData.disconnect_time or get_time())
    self:SetData("gold_over",mData.gold_over or 0)
    self:SetData("silver_over",mData.silver_over or 0)
    self:SetData("gold_owe", mData.gold_owe or 0)
    self:SetData("silver_owe", mData.silver_owe or 0)
    self:SetData("org_offer",mData.org_offer or 0)
    self:SetData("freeze_org_offer",mData.freeze_org_offer or 0)
    self:SetData("sk_point",mData.sk_point or 0)
    self:SetData("autopf", mData.autopf)
    self:SetData("jjc_point", mData.jjc_point or 0)
    self:SetData("challenge_point", mData.challenge_point or 0)
    self:SetData("ban_time", mData.ban_time or 0)
    self:SetData("login_time", mData.login_time or 0)
    self:SetData("auto_fight", mData.auto_fight or 0)
    self:SetData("orgtask_taskinfo",mData.orgtask_taskinfo)
    self:SetData("vigor", mData.vigor)
    self:SetData("leaderpoint", mData.leaderpoint)
    self:SetData("xiayipoint", mData.xiayipoint)
    self:SetData("summonpoint", mData.summonpoint)
    self:SetData("storypoint", mData.storypoint)
    self:SetData("offset", mData.offset)
    self:SetData("chumopoint", mData.chumopoint)

    self.m_oVisualMgr:Load(mData.visual_info or {})
    self.m_oGiftMgr:Load(mData.gift_info or {})
    self.m_oVigorCtrl:Load(mData.vigor_info or {})
end

function CPlayerActiveCtrl:Save()
    local mData = {}

    mData.scene_info = self:GetData("scene_info")
    mData.hp = self:GetData("hp")
    mData.mp = self:GetData("mp")
    mData.sp = self:GetData("sp")
    mData.gold = self:GetData("gold")
    mData.silver = self:GetData("silver")
    mData.wuxun = self:GetData("wuxun")
    mData.jjcpoint = self:GetData("jjcpoint")
    mData.exp = self:GetData("exp")
    mData.chubeiexp = self:GetData("chubeiexp")
    mData.energy = self:GetData("energy")
    mData.disconnect_time = self:GetData("disconnect_time")
    mData.gold_over = self:GetData("gold_over")
    mData.silver_over = self:GetData("silver_over")
    mData.org_offer = self:GetData("org_offer")
    mData.gold_owe = self:GetData("gold_owe", 0)
    mData.silver_owe = self:GetData("silver_owe",0)
    mData.freeze_org_offer = self:GetData("freeze_org_offer")
    mData.sk_point = self:GetData("sk_point")
    mData.autopf = self:GetData("autopf")
    mData.jjc_point = self:GetData("jjc_point")
    mData.challenge_point = self:GetData("challenge_point")
    mData.ban_time = self:GetData("ban_time")
    mData.login_time = self:GetData("login_time")
    mData.auto_fight = self:GetData("auto_fight", 0)
    mData.orgtask_taskinfo = self:GetData("orgtask_taskinfo")
    mData.vigor = self:GetData("vigor")
    mData.leaderpoint = self:GetData("leaderpoint")
    mData.xiayipoint = self:GetData("xiayipoint")
    mData.summonpoint = self:GetData("summonpoint")
    mData.storypoint = self:GetData("storypoint")
    mData.offset = self:GetData("offset")
    mData.chumopoint = self:GetData("chumopoint")

    mData.visual_info = self.m_oVisualMgr:Save()
    mData.gift_info = self.m_oGiftMgr:Save()
    mData.vigor_info = self.m_oVigorCtrl:Save()
    return mData
end

function CPlayerActiveCtrl:NewHour5(oPlayer)
    self:ReSetEnergy(oPlayer)
end

function CPlayerActiveCtrl:GetDisconnectTime()
    return self:GetData("disconnect_time")
end

function CPlayerActiveCtrl:SetDisconnectTime(iTime)
    iTime = iTime or get_time()
    self:SetData("disconnect_time", iTime)
end

function CPlayerActiveCtrl:GetGoldLimit(iGrade)
    local res = require "base.res"
    local mData = res["daobiao"]["goldlimit"]
    local iLimitGrade = 0
    for _,mLimit in pairs(mData) do
        if mLimit["grade"] <= iGrade then
            if iLimitGrade <= mLimit["grade"] then
                iLimitGrade = mLimit["grade"]
            end
        end
    end
    iLimitGrade = math.min(iLimitGrade,50)
    local mData = res["daobiao"]["goldlimit"][iLimitGrade]
    return mData["max"]
end

function CPlayerActiveCtrl:GetSilverLimit(iGrade)
    local res = require "base.res"
    local mData = res["daobiao"]["silverlimit"]
    local iLimitGrade = 0
    for _,mLimit in pairs(mData) do
        if mLimit["grade"] <= iGrade then
            if iLimitGrade <= mLimit["grade"] then
                iLimitGrade = mLimit["grade"]
            end
        end
    end
    iLimitGrade = math.min(iLimitGrade,50)
    local mData = res["daobiao"]["silverlimit"][iLimitGrade]
    return mData["max"]
end

function CPlayerActiveCtrl:ValidGold(iVal,mArgs)
    mArgs = mArgs or {}
    local iGold = self:GetData("gold",0)
    assert(iGold>=0,string.format("%d gold err %d",self:GetInfo("pid"),iGold))
    assert(iVal>0,string.format("%d  validgold err %d",self:GetInfo("pid"),iVal))
    if iGold >= iVal then
        return true
    end
    local sTip = mArgs.tip
    if not sTip then
        sTip = "金币不足"
    end
    if not mArgs.cancel_tip then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(self:GetInfo("pid"),sTip)
    end
    return false
end

function CPlayerActiveCtrl:LogGoldData()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mLogData = oPlayer and oPlayer:LogData() or {pid=iPid}
    mLogData["gold_old"] = self:GetData("gold", 0)
    mLogData["gold_over_old"] = self:GetData("gold_over", 0)
    mLogData["gold_owe_old"] = self:GetData("gold_owe", 0)
    return mLogData
end

function CPlayerActiveCtrl:RewardGold(iVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    if iVal<=0 then
        record.warning(string.format("rewardgold %s %s %s",self:GetInfo("pid"),iVal,sReason))
        return
    end

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iFortune = oPlayer.m_oTodayMorning:Query("signfortune", 0)
    if mArgs["fortune"] and iFortune == gamedefines.SIGNIN_FORTUNE.CSD then
        local iEffect = res["daobiao"]["huodong"]["signin"]["fortune"][iFortune]["effect"]
        iVal = iVal + math.floor(iVal * iEffect / 100)
    end
    local iMaxGold
    local iOverGold
    local iOldVal = self:GetData("gold",0)
    local sMsg = oToolMgr:FormatColorString("你获得了#gold#cur_3", {gold = iVal})
    local mLogData = self:LogGoldData()
    mLogData["gold_add"] = iVal
    mLogData["reason"] = sReason

    local iAddGold = iVal
    local iPayBack = 0
    local iOweGold = self:GetData("gold_owe", 0)
    if iOweGold > 0 then
        iPayBack = math.min(iOweGold, iAddGold)
        iOweGold = iOweGold - iPayBack
        iAddGold = iAddGold - iPayBack
        self:SetData("gold_owe", iOweGold)
    end

    if iAddGold > 0 and oPlayer then
        local iGrade = oPlayer:GetGrade()
        iMaxGold = self:GetGoldLimit(iGrade)
        local iOverGold = self:GetData("gold_over",0)
        if self:GetData("gold",0) >= iMaxGold  and 0 ~= iOverGold then
            self:SetData("gold_over",iOverGold+iAddGold)
            oPlayer:PropChange("gold_over")
            if not mArgs.cancel_tip then
                oPlayer:SendNotification(1104)
                oWorldMgr:SetRewardNotify(oPlayer:GetPid(), {gold=iVal})
            end

            mLogData["gold_over_now"] = self:GetData("gold_over", 0)
            mLogData["gold_owe_now"] = self:GetData("gold_owe", 0)
            mLogData["gold_now"] = self:GetData("gold", 0)
            record.log_db("money", "add_gold", mLogData)
            return
        end
    end

    local iGold = self:GetData("gold",0)

    iGold = iGold + iAddGold
    self:SetData("gold",iGold)

    if iMaxGold and iGold > iMaxGold then
        iOverGold = iGold - iMaxGold
        self:SetData("gold_over",iOverGold)
        self:SetData("gold",iMaxGold)
        oPlayer:PropChange("gold_over")
    end

    oPlayer:PropChange("gold")
    local oChatMgr = global.oChatMgr
    if not mArgs.cancel_chat then
        if iPayBack>0 then
            if iOweGold>0 then
                local sText = oToolMgr:GetTextData(1013,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {gold = {iPayBack, iOweGold}})
            elseif iOweGold == 0 then
                local sText = oToolMgr:GetTextData(1014,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {gold = {iPayBack}})
            end
        end
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        oWorldMgr:SetRewardNotify(oPlayer:GetPid(), {gold=iVal})
    end

    if iOverGold and iOverGold ~= 0 then
        if not mArgs.cancel_tip then
            oPlayer:SendNotification(1104)
        end
        local oMailMgr = global.oMailMgr
        local mData, name = oMailMgr:GetMailInfo(1002)
        local sMsg = oToolMgr:FormatColorString(mData.context, {goldover = iOverGold, carrymax =iMaxGold})
        mData.context = sMsg
        oMailMgr:SendMail(0, name, self:GetInfo("pid"), mData, 0)
    end

    mLogData["gold_over_now"] = self:GetData("gold_over", 0)
    mLogData["gold_owe_now"] = self:GetData("gold_owe", 0)
    mLogData["gold_now"] = self:GetData("gold", 0)
    record.log_db("money", "add_gold", mLogData)
    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.GOLD, iVal, iOldVal, sReason)
end

function CPlayerActiveCtrl:ResumeGold(iVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    local iResumeGold = iVal
    local iGold = self:GetData("gold",0)
    local iOldVal = iGold
    local iOweGold = self:GetData("gold_owe",0)
    assert(iVal>0,string.format("%d gold cost err %d",self:GetInfo("pid"),iVal))

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iOverGold = self:GetData("gold_over",0)
    local mLogData = self:LogGoldData()
    if iOverGold > 0 then
        local iDelGold = math.min(iResumeGold,iOverGold)
        iOverGold = iOverGold - iDelGold
        iResumeGold = iResumeGold - iDelGold
        self:SetData("gold_over",iOverGold)
        oPlayer:PropChange("gold_over")
    end
    iGold = iGold - iResumeGold
    if iGold<0 then
        iOweGold = iOweGold - iGold
        iGold = 0
    end
    self:SetData("gold",iGold)
    self:SetData("gold_owe",iOweGold)

    oPlayer:PropChange("gold")
    local sMsg = oToolMgr:FormatColorString("你消耗了#gold#cur_3", {gold = iVal})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if mArgs.tips then
        sMsg = mArgs.tips
        oNotifyMgr:Notify(self:GetInfo("pid"),sMsg)
    end
        
    mLogData["gold_now"] = self:GetData("gold", 0)
    mLogData["gold_sub"] = iVal
    mLogData["gold_owe_now"] = iOweGold
    mLogData["gold_over_now"] = self:GetData("gold_over", 0)
    mLogData["reason"] = sReason
    mLogData["subreason"] = mArgs.subreason or ""
    record.log_db("money", "sub_gold", mLogData)

    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.GOLD, -iVal, iOldVal, sReason)
end

function CPlayerActiveCtrl:ValidSilver(iVal,mArgs)
    mArgs = mArgs or {}
    local iSilver = self:GetData("silver",0)
    assert(iSilver>=0,string.format("%d silver err %d",self:GetInfo("pid"),iSilver))
    assert(iVal>0,string.format("%d cost silver err %d",self:GetInfo("pid"),iVal))
    if iSilver >= iVal then
        return true
    end
    local sTip = mArgs.tip
    if not sTip then
        sTip = "银币不足"
    end
    if not mArgs.cancel_tip then
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(self:GetInfo("pid"),sTip)
    end
    return false
end

function CPlayerActiveCtrl:LogSilverData()
    local oWorldMgr = global.oWorldMgr
    local iPid = self:GetInfo("pid")
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mLogData = oPlayer and oPlayer:LogData() or {pid=iPid}
    mLogData["silver_old"] = self:GetData("silver", 0)
    mLogData["silver_over_old"] = self:GetData("silver_over", 0)
    mLogData["silver_owe_old"] = self:GetData("silver_owe",0)
    return mLogData
end

function CPlayerActiveCtrl:RewardSilver(iVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    assert(iVal>0,string.format("%s  rewardsilver err %s",self:GetInfo("pid"),iVal))

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iFortune = oPlayer.m_oTodayMorning:Query("signfortune", 0)
    local iAddSilver = 0
    if mArgs["fortune"] and iFortune == gamedefines.SIGNIN_FORTUNE.CYHT then
        local iEffect = res["daobiao"]["huodong"]["signin"]["fortune"][iFortune]["effect"]
        iAddSilver = math.floor(iVal * iEffect / 100)
        iVal = iVal + iAddSilver
    end

    local iGrade = oPlayer:GetGrade()
    local iMaxSilver = self:GetSilverLimit(iGrade)
    assert(iMaxSilver>0,string.format("%d RewardSilver %d %d",self:GetInfo("pid"),iMaxSilver,iGrade))
    
    local mLogData = self:LogSilverData()
    mLogData["silver_add"] = iVal
    mLogData["reason"] = sReason
    local sMsg = oToolMgr:FormatColorString("你获得了#silver#cur_4", {silver = iVal})

    local iAddSilver = iVal
    local iPayBack = 0
    local iOweSilver = self:GetData("silver_owe", 0)
    if iOweSilver > 0 then
        iPayBack = math.min(iOweSilver, iAddSilver)
        iOweSilver = iOweSilver - iPayBack
        iAddSilver = iAddSilver - iPayBack
        self:SetData("silver_owe", iOweSilver)
    end

    if oPlayer and iAddSilver>0 then
        local iOverSilver = self:GetData("silver_over",0)
        if self:GetData("silver",0) >=  iMaxSilver and 0 ~= iOverSilver then
            self:SetData("silver_over",iOverSilver+iAddSilver)
            oPlayer:PropChange("silver_over")
            if not mArgs.cancel_chat then
                oChatMgr:HandleMsgChat(oPlayer, sMsg)
            end
            if not mArgs.cancel_tip then
                oPlayer:SendNotification(1105)
                oWorldMgr:SetRewardNotify(self:GetInfo("pid"), {silver=iVal})
            end
            mLogData["silver_now"] = self:GetData("silver", 0)
            mLogData["silver_over_now"] = self:GetData("silver_over", 0)
            mLogData["silver_owe_now"] = self:GetData("silver_owe", 0)
            record.log_db("money", "add_silver", mLogData)
            return
        end
    end

    local iSilver = self:GetData("silver",0)
    if iAddSilver > 0 then
        iSilver = iSilver + iAddSilver
        self:SetData("silver",iSilver)
    end
    
    local iOverSilver
    if iSilver >= iMaxSilver then
        iOverSilver = iSilver - iMaxSilver
        self:SetData("silver",iMaxSilver)
        self:SetData("silver_over",iOverSilver)
    end

    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    oPlayer:PropChange("silver")
    if not mArgs.cancel_chat then
        if iPayBack>0 then
            if iOweSilver>0 then
                local sText = oToolMgr:GetTextData(1015,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {silver = {iPayBack, iOweSilver}})
            elseif iOweSilver == 0 then
                local sText = oToolMgr:GetTextData(1016,{"shop"})
                sMsg = sMsg .. oToolMgr:FormatColorString(sText, {silver = {iPayBack}})
            end
        end
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        oWorldMgr:SetRewardNotify(self:GetInfo("pid"), {silver=iVal})
    end

    if iOverSilver and 0 ~= iOverSilver then
        oPlayer:SendNotification(1105)
        oPlayer:PropChange("silver_over")
        local oMailMgr = global.oMailMgr
        local mData, name = oMailMgr:GetMailInfo(1003)
        local sMsg = oToolMgr:FormatColorString(mData.context, {silverover = iOverSilver, carrymax =iMaxSilver})
        mData.context = sMsg
        oMailMgr:SendMail(0, name, self:GetInfo("pid"), mData, 0)
    end

    mLogData["silver_now"] = self:GetData("silver", 0)
    mLogData["silver_over_now"] = self:GetData("silver_over", 0)
    mLogData["silver_owe_now"] = self:GetData("silver_owe", 0)
    record.log_db("money", "add_silver", mLogData)
    
    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.SILVER, iVal, iOldVal, sReason)
end

function CPlayerActiveCtrl:ResumeSilver(iVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    local iCostSilver = iVal
    local iSilver = self:GetData("silver",0)
    local iOldVal = iSilver
    local iOweSilver = self:GetData("silver_owe",0) 
    assert(iVal>0,string.format("%d cost silver err %d",self:GetInfo("pid"),iVal))
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mLogData = self:LogSilverData()

    
    local iOverSilver = self:GetData("silver_over",0)
    if iOverSilver > 0  then
        local iDelSilver = math.min(iCostSilver,iOverSilver)
        iOverSilver = iOverSilver - iDelSilver
        iCostSilver = iCostSilver - iDelSilver
        self:SetData("silver_over",iOverSilver)
        oPlayer:PropChange("silver_over")
    end
    iSilver = iSilver - iCostSilver
    if iSilver<0 then
        iOweSilver = iOweSilver - iSilver
        iSilver = 0  
    end
    self:SetData("silver",iSilver)
    self:SetData("silver_owe",iOweSilver)
    oPlayer:PropChange("silver")

    local sMsg = oToolMgr:FormatColorString("你消耗了#silver#cur_4", {silver = iVal})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    mLogData["silver_sub"] = iVal
    mLogData["reason"] = sReason
    mLogData["silver_now"] = self:GetData("silver", 0)
    mLogData["silver_over_now"] = self:GetData("silver_over_now", 0)
    mLogData["silver_owe_now"] = self:GetData("silver_owe", 0)
    mLogData["subreason"] = mArgs.subreason or ""
    record.log_db("money", "sub_silver", mLogData)

    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.SILVER, -iVal, iOldVal, sReason)
end

function CPlayerActiveCtrl:RewardExp(iVal,sReason,mArgs)
    local iExp = self:GetData("exp",0)
    local iSubChuBei = 0
    mArgs = mArgs or {}
    assert(iVal>0,string.format("%d exp err %d %d",self:GetInfo("pid"),iExp,iVal))
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local iPlayerGrade = oPlayer:GetGrade()
    local iServerGrade = oPlayer:GetServerGrade()
    local iServerGradeLimit = oPlayer:GetServerGradeLimit()
    local mLogData = oPlayer:LogData()
    mLogData["exp_old"] = iExp
    mLogData["exp_add"] = iVal
    mLogData["grade_old"] = iPlayerGrade
    mLogData["subchubei"] = 0
    mLogData["nowchubei"] = self:GetData("chubeiexp", 0)

    local iAddExpRatio = oPlayer.m_oStateCtrl:GetAddExtraExpRatio()
    if not mArgs.bIgnoreFortune then
        local iFortune = oPlayer.m_oTodayMorning:Query("signfortune",0)
        if iFortune == gamedefines.SIGNIN_FORTUNE.FXGZ then
            local iEffect = res["daobiao"]["huodong"]["signin"]["fortune"][iFortune]["effect"]
            iAddExpRatio = iAddExpRatio + iEffect
        end
    end
    if mArgs and mArgs.iAddexpRatio then
        iAddExpRatio = iAddExpRatio + mArgs.iAddexpRatio
    end
    local iSLVRadio  = 0
    if mArgs.bEffect then
        iSLVRadio = oPlayer.m_oStateCtrl:GetAddServerExpRatio()
    end
    if mArgs.bCancelAddRatio then
        iAddExpRatio = 0
        iSLVRadio = math.min(0, iSLVRadio)
    end
    local iBaseExp = iVal
    iVal = math.ceil(iBaseExp * (100 + iAddExpRatio) / 100 * (100 + iSLVRadio) / 100)
    local sLeaderMsg
    if mArgs.iLeaderRatio and mArgs.iLeaderRatio > 0 then
        local iLeaderExp = math.ceil( iBaseExp * mArgs.iLeaderRatio/ 100 * (100 + iSLVRadio) /100 )
        sLeaderMsg = oToolMgr:FormatColorString("队长获得#exp额外经验", {exp= iLeaderExp })
    end 
    local lMsgs = {}
    if iVal > 0 then
        local sMsg
        local sChatMsg
        iSubChuBei = math.min(self:GetData("chubeiexp"), iVal)
        if iSubChuBei > 0 and not mArgs.bCancelAddRatio then
            self:SetData("chubeiexp", self:GetData("chubeiexp") - iSubChuBei)
            oPlayer:PropChange("chubeiexp")
            mLogData["subchubei"] = iSubChuBei
            mLogData["nowchubei"] = self:GetData("chubeiexp", 0)
        else
            iSubChuBei = 0
        end

        local iGainExp = iVal + iSubChuBei
        
        if oPlayer:GetGrade() < iServerGradeLimit then
            local iSetExp = iExp + iGainExp
            self:SetData("exp", iSetExp)
            oPlayer:PropChange("exp")
            oPlayer:CheckUpGrade()   
        else
            local iExpLimit = oPlayer:MaxFutureExp()
            if iExp < iExpLimit then
                local iSetExp = math.min(iExp + iGainExp, iExpLimit)
                self:SetData("exp", iSetExp)
                oPlayer:PropChange("exp")
            else 
                iGainExp = 0
            end
        end

        if iGainExp == 0 then
            sMsg = "达到目前可获取的上限将不再获取"
            oNotifyMgr:Notify(sMsg)
            sChatMsg = sMsg
        elseif iSubChuBei > 0  then
            sMsg = oToolMgr:FormatColorString("你获得了#exp#cur_6", {exp = iGainExp})
            sChatMsg = oToolMgr:FormatColorString("你获得了#exp#cur_6,其中#exp经验为储备经验加成", {exp = {iGainExp,iSubChuBei}})
        else
            sMsg = oToolMgr:FormatColorString("你获得了#exp#cur_6", {exp = iGainExp })
            sChatMsg = sMsg
        end

        if not mArgs.cancel_chat then
            table.insert(lMsgs, sMsg)
            oChatMgr:HandleMsgChat(oPlayer, sChatMsg)
            if sLeaderMsg then
                oChatMgr:HandleMsgChat(oPlayer, sLeaderMsg)
            end
        end

        if not mArgs.cancel_tip then
            oWorldMgr:SetRewardNotify(oPlayer:GetPid(), {exp = iGainExp})
            if sLeaderMsg then
                oPlayer:NotifyMessage(sLeaderMsg)
            end

        end
    end
    mLogData["exp_now"] = self:GetData("exp", 0)
    mLogData["grade_now"] = oPlayer:GetGrade()
    mLogData["reason"] = sReason
    record.log_db("player", "exp", mLogData)

    -- 数据中心lo
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["role_level_before"] = iPlayerGrade
    mAnalyLog["role_level_after"] = oPlayer:GetGrade()
    mAnalyLog["reason"] = sReason
    mAnalyLog["exp"] = iVal
    analy.log_data("RoleGainExp", mAnalyLog)
    local mResult = {}
    mResult.exp = iVal
    mResult.chubei_exp = iSubChuBei
    mResult.lMsgs = lMsgs
    return mResult
end

function CPlayerActiveCtrl:AddChubeiExp(iVal,sReason)
    local iChubeiExp = self:GetData("chubeiexp",0)
    assert(iVal,string.format("%d exp err %d %d",self:GetInfo("pid"),iChubeiExp,iVal))

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    local mLogData = oPlayer:LogData()
    mLogData["chubei_old"] = iChubeiExp
    mLogData["chubei_add"] = iVal
    mLogData["reason"] = sReason

    local iChubeiExp = iChubeiExp + iVal
    self:SetData("chubeiexp",iChubeiExp)
    oPlayer:PropChange("chubeiexp")

    mLogData["chubei_now"] = iChubeiExp
    record.log_db("player", "chubei_exp", mLogData)
end

function CPlayerActiveCtrl:ValidWuXun(iSubValue,mArgs)
    mArgs = mArgs or {}
    local pid =self:GetInfo("pid")
    local iValue = self:GetData("wuxun",0)
    assert(iValue>=0,string.format("%d wuxun err %d",pid,iValue))
    assert(iSubValue>0,string.format("%d cost wuxun err %d",pid,iSubValue))
    if iValue >= iSubValue then
        return true
    end
    
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or global.oToolMgr:GetTextData(1010, {"moneypoint"})
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(pid,sTip)
    end
    return false
end

function CPlayerActiveCtrl:RewardWuXun(iAddValue,sReason,mArgs)
    mArgs = mArgs or {}
    local pid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    assert(oPlayer,string.format("offline %s",pid))
    assert(iAddValue>0,string.format("%d wuxun err %d",pid,iAddValue))
    local iValue = self:GetData("wuxun",0)
    self:SetData("wuxun", iValue+iAddValue)
    oPlayer:PropChange("wuxun")

    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = oToolMgr:FormatColorString("你获得了#wuxun#jifen_1", {wuxun = iAddValue})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
--[[
    if not mArgs.cancel_tip then
        oNotifyMgr:Notify(pid,sMsg)
    end
--]]
    local mLogData = oPlayer:LogData()
    mLogData["wuxun_old"] = iValue
    mLogData["wuxun_add"] = iAddValue
    mLogData["wuxun_now"] = iValue + iAddValue
    mLogData["reason"] = sReason
    record.log_db("money", "add_wuxun", mLogData)
end

function CPlayerActiveCtrl:ResumeWuXun(iSubVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    local pid = self:GetInfo("pid")
    local iValue = self:GetData("wuxun",0)
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    assert(iValue>0,string.format("%d silver err %d",pid,iValue))
    assert(iSubVal>0,string.format("%d cost silver err %d",pid,iSubVal))
    assert(oPlayer,string.format("offline %s",pid))
    self:SetData("wuxun",iValue - iSubVal)
    oPlayer:PropChange("wuxun")

    local sMsg = oToolMgr:FormatColorString("你消耗了#wuxun#jifen_1", {wuxun = iSubVal})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        oNotifyMgr:Notify(pid,sMsg)
    end
    local mLogData = oPlayer:LogData()
    mLogData["wuxun_old"] = iValue
    mLogData["wuxun_sub"] = iSubVal
    mLogData["wuxun_now"] = iValue - iSubVal
    mLogData["reason"] = sReason
    record.log_db("money", "sub_wuxun", mLogData)
end


function CPlayerActiveCtrl:ValidJJCPoint(iSubValue,mArgs)
    mArgs = mArgs or {}
    local pid =self:GetInfo("pid")
    local iValue = self:GetData("jjcpoint",0)
    assert(iValue>=0,string.format("%d jjcpoint err %d",pid,iValue))
    assert(iSubValue>0,string.format("%d cost jjcpoint err %d",pid,iSubValue))
    if iValue >= iSubValue then
        return true
    end
    
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or global.oToolMgr:GetTextData(1011, {"moneypoint"})
        local oNotifyMgr = global.oNotifyMgr
        oNotifyMgr:Notify(pid,sTip)
    end
    return false
end

function CPlayerActiveCtrl:RewardJJCPoint(iAddValue,sReason,mArgs)
    mArgs = mArgs or {}
    local pid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    assert(oPlayer,string.format("offline %s",pid))
    assert(iAddValue>0,string.format("%d jjcpoint err %d",pid,iAddValue))
    local iValue = self:GetData("jjcpoint",0)
    self:SetData("jjcpoint", iValue+iAddValue)
    oPlayer:PropChange("jjcpoint")

    local oToolMgr = global.oToolMgr
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = oToolMgr:FormatColorString("你获得了#jjcpoint#jifen_2", {jjcpoint = iAddValue})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        oNotifyMgr:Notify(pid,sMsg)
    end
    local mLogData = oPlayer:LogData()
    mLogData["jjcpoint_old"] = iValue
    mLogData["jjcpoint_add"] = iAddValue
    mLogData["jjcpoint_now"] = iValue + iAddValue
    mLogData["reason"] = sReason
    record.log_db("money", "add_jjcpoint", mLogData)
end

function CPlayerActiveCtrl:ResumeJJCPoint(iSubVal,sReason,mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local oToolMgr = global.oToolMgr
    mArgs = mArgs or {}
    local pid = self:GetInfo("pid")
    local iValue = self:GetData("jjcpoint",0)
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    assert(iValue>0,string.format("%d silver err %d",pid,iValue))
    assert(iSubVal>0,string.format("%d cost silver err %d",pid,iSubVal))
    assert(oPlayer,string.format("offline %s",pid))
    self:SetData("jjcpoint",iValue - iSubVal)
    oPlayer:PropChange("jjcpoint")

    local sMsg = oToolMgr:FormatColorString("你消耗了#jjcpoint#jifen_2", {jjcpoint = iSubVal})
    if not mArgs.cancel_chat then
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        oNotifyMgr:Notify(pid,sMsg)
    end
    local mLogData = oPlayer:LogData()
    mLogData["jjcpoint_old"] = iValue
    mLogData["jjcpoint_sub"] = iSubVal
    mLogData["jjcpoint_now"] = iValue - iSubVal
    mLogData["reason"] = sReason
    record.log_db("money", "sub_jjcpoint", mLogData)
end


function CPlayerActiveCtrl:SetDurableSceneInfo(iMapId, mPos)
    local m = {
        map_id = iMapId,
        pos = mPos,
    }
    self:SetData("scene_info", m)
end

function CPlayerActiveCtrl:GetDurableSceneInfo()
    return self:GetData("scene_info")
end

function CPlayerActiveCtrl:GetNowWar()
    local m = self.m_mNowWarInfo
    if not m then
        return
    end
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(m.now_war)
end

function CPlayerActiveCtrl:GetWarStatus()
    local oWar = self:GetNowWar()
    if not oWar then
        return gamedefines.WAR_STATUS.NO_WAR
    end
    if oWar:InWar(self:GetInfo("pid")) then
        return gamedefines.WAR_STATUS.IN_WAR
    end
    if oWar:InObserver(self:GetInfo("pid")) then
        return gamedefines.WAR_STATUS.IN_OBSERVER
    end
    return gamedefines.WAR_STATUS.NO_WAR
end

function CPlayerActiveCtrl:GetNowScene()
    local m = self.m_mNowSceneInfo
    if not m then
        return
    end
    local oSceneMgr = global.oSceneMgr
    return oSceneMgr:GetScene(m.now_scene)
end

function CPlayerActiveCtrl:GetNowPos()
    if not self.m_mNowSceneInfo then return {} end

    local mNowPos
    if self.m_oSceneShareObj then
        mNowPos = self.m_oSceneShareObj:GetNowPos()
    end
    local m = self.m_mNowSceneInfo
    if mNowPos then
        m.now_pos = mNowPos
    end
    return m.now_pos
end

function CPlayerActiveCtrl:SetNowSceneInfo(mInfo)
    local m = self.m_mNowSceneInfo
    if not m then
        self.m_mNowSceneInfo = {}
        m = self.m_mNowSceneInfo
    end
    if mInfo.now_scene then
        m.now_scene = mInfo.now_scene
    end
    if mInfo.now_pos then
        m.now_pos = mInfo.now_pos
    end
end

function CPlayerActiveCtrl:ClearNowSceneInfo()
    self.m_mNowSceneInfo = {}
end

function CPlayerActiveCtrl:SetNowWarInfo(mInfo)
    local m = self.m_mNowWarInfo
    if not m then
        self.m_mNowWarInfo = {}
        m = self.m_mNowWarInfo
    end
    if mInfo.now_war then
        m.now_war = mInfo.now_war
    end
end

function CPlayerActiveCtrl:ClearNowWarInfo()
    self.m_mNowWarInfo = {}
end

function CPlayerActiveCtrl:ValidOrgOffer(iVal, mArgs)
    assert(iVal>0, string.format("valid orgoffer error ival: %s", iVal))
    if self:GetData("org_offer") >= iVal then return true end

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or "帮贡不足"
        global.oNotifyMgr:Notify(self:GetInfo("pid"), sTip)
    end
    return false
end

function CPlayerActiveCtrl:RewardOrgOffer(iVal, sReason, mArgs)
    assert(iVal>0, string.format("reward org offer error iVal:%s", iVal))
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iOffer, iExtVal = self:GetData("org_offer", 0), 0
    local oOrg = oPlayer:GetOrg()
    if oOrg then
        oOrg:AddOrgOffer(iPid, iVal)
        oPlayer:RefreshCulSkillUpperLevel()
    end
    if self:GetFreezeOrgOffer() > 0 then
        iExtVal = math.min(self:GetFreezeOrgOffer(), iVal)
        self:AddFreezeOrgOffer(-iExtVal)
    end
    self:SetData("org_offer", iOffer + iVal + iExtVal)
    oPlayer:PropChange("org_offer")

    local sMsg
    if iExtVal > 0 then
        sMsg = global.oToolMgr:FormatColorString("你获得了#amount帮贡，同时解冻了#amount帮贡", {amount = {iVal, iExtVal}})
    else
        sMsg = global.oToolMgr:FormatColorString("你获得了#amount帮贡", {amount = iVal})
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(sMsg)
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end

    local mLogData = oPlayer:LogData()
    mLogData.reason = sReason
    mLogData.orgoffer_old = iOffer
    mLogData.org_id = oPlayer:GetOrgID() or 0
    mLogData.orgoffer_now = self:GetData("org_offer", 0)
    mLogData.orgoffer_add = iVal
    mLogData.freeze_orgoffer_sub = iExtVal
    mLogData.freeze_orgoffer_now = self:GetFreezeOrgOffer()
    record.user("money", "add_orgoffer", mLogData)
    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.ORGOFFER, iVal, iOffer, sReason)
end

function CPlayerActiveCtrl:ResumeOrgOffer(iVal, sReason, mArgs)
    assert(iVal>0, string.format("resume orgoffer error iVal:%s", iVal))
    local iOffer = self:GetData("org_offer", 0)
    assert(iOffer>=iVal, string.format("resume orgoffer error2 offer:%s iVal:%s", iOffer, iVal))
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    self:SetData("org_offer", iOffer - iVal)
    oPlayer:PropChange("org_offer")

    local sMsg = global.oToolMgr:FormatColorString("你消耗了#amount帮贡", {amount = iVal})
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(sMsg)
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end

    local mLogData = oPlayer:LogData()
    mLogData.reason = sReason
    mLogData.orgoffer_old = iOffer
    mLogData.org_id = oPlayer:GetOrgID() or 0
    mLogData.orgoffer_now = self:GetData("org_offer", 0)
    mLogData.orgoffer_sub = -iVal
    record.user("money", "sub_orgoffer", mLogData)
    self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.ORGOFFER, -iVal, iOffer, sReason) 
end

function CPlayerActiveCtrl:AddOrgOffer(iVal, sReason)
    local oldVal = self:GetData("org_offer")
    self:SetData("org_offer", math.max(0, oldVal+iVal))

    -- 数据中心log
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        self:LogAnalyInfo(oPlayer, gamedefines.MONEY_TYPE.ORGOFFER, iVal, oldVal, sReason)
    end
end

function CPlayerActiveCtrl:AddFreezeOrgOffer(iVal)
    local oldVal = self:GetData("freeze_org_offer")
    self:SetData("freeze_org_offer", math.max(0, oldVal+iVal))
end

function CPlayerActiveCtrl:GetFreezeOrgOffer()
    return self:GetData("freeze_org_offer", 0)
end

function CPlayerActiveCtrl:GetOffer()
    return self:GetData("org_offer", 0)
end

function CPlayerActiveCtrl:ValidSkillPoint(iPoint,mArgs)
    return self:GetData("sk_point") >= iPoint
end

function CPlayerActiveCtrl:AddSkillPoint(iPoint, sReason, mArgs)
    assert(iPoint > 0, string.format("add skillpoint err: %d %s", iPoint, sReason))
    self:SetData("sk_point", math.max(self:GetData("sk_point") + iPoint, 0))

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local sMsg = global.oToolMgr:FormatColorString("你获得了#skpoint招式经验", {skpoint = iPoint})
        if not mArgs or not mArgs.cancel_chat then
            global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
        end
        oPlayer:PropChange("skill_point")
    end
end

function CPlayerActiveCtrl:ResumeSkillPoint(iPoint, sReason, mArgs)
    assert(iPoint > 0, string.format("resume skillpoint err: %d %s", iPoint, sReason))
    self:SetData("sk_point", math.max(self:GetData("sk_point") - iPoint, 0))

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        oPlayer:PropChange("skill_point")
    end
end

function CPlayerActiveCtrl:UpgradeCoin()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if oPlayer then
        local iGrade = oPlayer:GetGrade()
        local iOverGold = self:GetData("gold_over")
        if iOverGold and iOverGold > 0 then
            local mLogGoldData = self:LogGoldData()
            local iGoldUpgrade = self:GetGoldLimit(iGrade + 1) - self:GetGoldLimit(iGrade)
            if iGoldUpgrade <= 0 then
                iGoldUpgrade = self:GetGoldLimit(iGrade)
            end
            local iGoldAdd = math.min(iOverGold ,iGoldUpgrade)
            local iGold = self:GetData("gold")
            iGoldAdd = iGold + iGoldAdd
            self:SetData("gold", iGoldAdd)
            if iGoldAdd > self:GetGoldLimit(iGrade) then
                self:SetData("gold", self:GetGoldLimit(iGrade))
                iGoldAdd = self:GetData("gold")
            end
            oPlayer:PropChange("gold")
            iGoldAdd = iGoldAdd - iGold
            self:SetData("gold_over", math.max(0, iOverGold - iGoldAdd))
            oPlayer:PropChange("gold_over")

            mLogGoldData["gold_add"] = iGoldAdd
            mLogGoldData["gold_now"] = self:GetData("gold", 0)
            mLogGoldData["gold_over_now"] = self:GetData("gold_over", 0)
            mLogGoldData["gold_owe_now"] = self:GetData("gold_owe", 0)
            mLogGoldData["reason"] = "upgrade"
            record.log_db("money", "add_gold", mLogGoldData)
        end

        local iOverSilver = self:GetData("silver_over")
        if iOverSilver and iOverSilver > 0 then
            local mLogSilverData = self:LogSilverData()
            local iSilverUpgrade = self:GetSilverLimit(iGrade + 1) - self:GetSilverLimit(iGrade)
            if iSilverUpgrade <= 0 then
                iSilverUpgrade = self:GetSilverLimit(iGrade)
            end
            local iSilverAdd = math.min(iOverSilver ,iSilverUpgrade)
            local iSilver = self:GetData("silver")
            iSilverAdd = iSilver + iSilverAdd
            self:SetData("silver", iSilverAdd)
            if iSilverAdd > self:GetSilverLimit(iGrade) then
                self:SetData("silver", self:GetSilverLimit(iGrade))
                iSilverAdd = self:GetData("silver")
            end
            oPlayer:PropChange("silver")
            iSilverAdd = iSilverAdd - iSilver
            self:SetData("silver_over", math.max(0, iOverSilver - iSilverAdd))
            oPlayer:PropChange("silver_over")

            mLogSilverData["silver_add"] = iSilverAdd
            mLogSilverData["silver_now"] = self:GetData("silver", 0)
            mLogSilverData["silver_over_now"] = self:GetData("silver_over", 0)
            mLogSilverData["silver_owe_now"] = self:GetData("silver_owe", 0)
            mLogSilverData["reason"] = "upgrade"
            record.log_db("money", "add_silver", mLogSilverData)
        end
    end
end

function CPlayerActiveCtrl:SetAutoPerform(iAutoPf)
    self:SetData("autopf", iAutoPf)
end

function CPlayerActiveCtrl:GetAutoPerform()
    return self:GetData("autopf")
end

function CPlayerActiveCtrl:SetAutoFight(iAutoFight)
    self:SetData("auto_fight", iAutoFight)
end

function CPlayerActiveCtrl:GetAutoFight()
    return self:GetData("auto_fight")
end

function CPlayerActiveCtrl:PreLogin(oPlayer, bReEnter)
    self.m_oVisualMgr:PreLogin(oPlayer, bReEnter)
end

function CPlayerActiveCtrl:OnLogin(oPlayer, bReEnter)
    self.m_oGiftMgr:OnLogin(oPlayer, bReEnter)
    self:SetData("login_time", get_time())
    if not bReEnter then
        self:CheckResetEnergy(oPlayer)
    end
end

function CPlayerActiveCtrl:UnDirty()
    self.m_oGiftMgr:UnDirty()
    self.m_oVisualMgr:UnDirty()
    self.m_oVigorCtrl:UnDirty()
    super(CPlayerActiveCtrl).UnDirty(self)
end

function CPlayerActiveCtrl:IsDirty()
    if super(CPlayerActiveCtrl).IsDirty(self) then
        return true
    end
    if self.m_oGiftMgr:IsDirty() then
        return true
    end
    if self.m_oVisualMgr:IsDirty() then
        return true
    end
    if self.m_oVigorCtrl:IsDirty() then
        return true
    end
end

function CPlayerActiveCtrl:QuickTeamup(oPlayer, iAutoTargetId)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local pid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        if oTeam:IsLeader(pid) then
            oPlayer:Send("GS2COpenTeamAutoMatchUI", {auto_target=iAutoTargetId})
            return
        else
        -- elseif oTeam:IsShortLeave(pid) then
            local sMsg = oToolMgr:GetTextData(1021)
            global.oNotifyMgr:Notify(pid, sMsg)
            return
        end
    else
        oPlayer:Send("GS2COpenTeamAutoMatchUI", {auto_target=iAutoTargetId})
        return
    end
end

function CPlayerActiveCtrl:AddJJCPoint(iVal)
    local oldVal = self:GetData("jjc_point", 0)
    if iVal < 0 then
        iVal = math.max(iVal, -oldVal)
    end
    if iVal == 0 then
        return
    end
    self:SetData("jjc_point", math.max(0, oldVal+iVal))

    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local sMsg
    if iVal > 0 then
        sMsg = oToolMgr:FormatColorString("你获得了#jjc_point竞技积分", {jjc_point = iVal})
        --oNotifyMgr:Notify(self:GetInfo("pid"),sMsg)
    elseif iVal < 0 then
        sMsg = oToolMgr:FormatColorString("你消耗了#jjc_point竞技积分", {jjc_point = -iVal})
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
end

function CPlayerActiveCtrl:GetJJCPoint()
    return self:GetData("jjc_point", 0)
end

function CPlayerActiveCtrl:AddChallengePoint(iVal)
    local oldVal = self:GetData("challenge_point", 0)
    if iVal < 0 then
        iVal = math.max(iVal, -oldVal)
    end
    if iVal == 0 then
        return
    end
    self:SetData("challenge_point", math.max(0, oldVal+iVal))

    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oWorldMgr = global.oWorldMgr
    local oChatMgr = global.oChatMgr
    local sMsg
    if iVal > 0 then
        sMsg = oToolMgr:FormatColorString("你获得了#challenge_point挑战积分", {challenge_point = iVal})
        oNotifyMgr:Notify(self:GetInfo("pid"),sMsg)
    elseif iVal < 0 then
        sMsg = oToolMgr:FormatColorString("你消耗了#challenge_point挑战积分", {challenge_point = -iVal})
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
end

function CPlayerActiveCtrl:GetChallengePoint()
    return self:GetData("challenge_point", 0)
end

function CPlayerActiveCtrl:SetBanChat(iTime)
    self:SetData("ban_time", iTime)
end

function CPlayerActiveCtrl:IsBanChat()
    return get_time() < self:GetData("ban_time", 0) 
end

function CPlayerActiveCtrl:GetBanChatTime()
   return math.max(self:GetData("ban_time", 0) - get_time(), 0)
end

function CPlayerActiveCtrl:PackBackendInfo()
    return {
        login_time = self:GetData("login_time"),
        exp = self:GetData("exp"),  
        chubeiexp = self:GetData("chubeiexp"),
        gold = self:GetData("gold"),
        silver = self:GetData("silver"),
        org_offer = self:GetData("org_offer"),
        scene_info = self:GetData("scene_info"),
        wuxun = self:GetData("wuxun"),
        jjcpoint = self:GetData("jjcpoint"),
        energy = self:GetData("energy"),
        sk_point = self:GetData("sk_point"),
        vigor = self:GetData("vigor"),
        leaderpoint = self:GetData("leaderpoint"),
        xiayipoint = self:GetData("xiayipoint"),
        summonpoint = self:GetData("summonpoint"),
        storypoint = self:GetData("storypoint"),
        chumopoint = self:GetData("chumopoint")
    }
end

function CPlayerActiveCtrl:LogAnalyInfo(oPlayer, sMoneyType, iVal, iOldVal, sReason)
    -- 数据中心log
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["currency_type"] = sMoneyType
    mAnalyLog["num"] = iVal
    mAnalyLog["remain_currency"] = oPlayer:GetMoney(sMoneyType)
    mAnalyLog["reason"] = sReason
    analy.log_data("currency", mAnalyLog)
end


CPlayerVisualMgr = {}
CPlayerVisualMgr.__index = CPlayerVisualMgr
inherit(CPlayerVisualMgr, datactrl.CDataCtrl)

function CPlayerVisualMgr:New(pid)
    local o = super(CPlayerVisualMgr).New(self, {pid = pid})
    return o
end

function CPlayerVisualMgr:Release()
    super(CPlayerVisualMgr).Release(self)
end

function CPlayerVisualMgr:Save()
    local mData = {}
    if next(self.m_mCustomGlobalNpcs) then
        mData.custom_gnpcs = self.m_mCustomGlobalNpcs
    end
    if next(self.m_mVisibleNpcs) then
        mData.visible_npcs = self.m_mVisibleNpcs
    end
    if next(self.m_mVisibleSceneEffects) then
        mData.visible_scene_effects = self.m_mVisibleSceneEffects
    end
    if next(self.m_mSeenNpcs) then
        mData.seen_npcs = self.m_mSeenNpcs
    end
    mData.ghost_eye = self.m_iGhostEye
    return mData
end

function CPlayerVisualMgr:Load(mData)
    self.m_mCustomGlobalNpcs = table_to_int_key(mData.custom_gnpcs or {})
    self.m_mVisibleNpcs = table_to_int_key(mData.visible_npcs or {})
    self.m_mVisibleSceneEffects = table_to_int_key(mData.visible_scene_effects or {})
    self.m_mSeenNpcs = table_to_int_key(mData.seen_npcs or {}) -- 记录常驻npc特写开启过
    self.m_iGhostEye = mData.ghost_eye
end

function CPlayerVisualMgr:PreLogin(oPlayer, bReEnter)
    local mNet = {
        npcs = self:PackValueInfo(self.m_mVisibleNpcs),
        scene_effects = self:PackValueInfo(self.m_mVisibleSceneEffects),
    }
    local lMyGlobalNpcs = self:PackMyGlobalNpcs()
    if lMyGlobalNpcs and next(lMyGlobalNpcs) then
        mNet.npc_appears = lMyGlobalNpcs
    end
    if next(mNet) then
        oPlayer:Send("GS2CLoginVisibility", mNet)
    end

    local iGhostEye = self.m_iGhostEye
    if iGhostEye and 0~= iGhostEye then
        oPlayer:Send("GS2CLoginGhostEye", {open = iGhostEye})
    end
end

function CPlayerVisualMgr:GetMyGlobalNpc(iGlobalNpcType)
    return self.m_mCustomGlobalNpcs[iGlobalNpcType]
end

-- 参数为nil表示还原
function CPlayerVisualMgr:SetMyGlobalNpc(iGlobalNpcType, iFigureId, iGlobalDiaId, sTitle)
    local mData = {
        figure = iFigureId,
        title = sTitle,
        dialog = iGlobalDiaId,
    }
    if not next(mData) then
        mData = nil
    end
    self.m_mCustomGlobalNpcs[iGlobalNpcType] = mData
    self:Dirty()
end

function CPlayerVisualMgr:PackMyGlobalNpcInfo(iGlobalNpcType)
    local mInfo = self.m_mCustomGlobalNpcs[iGlobalNpcType]
    local iReset = 0
    if not mInfo then
        mInfo = {}
        iReset = 1
    end
    local mNetInfo = {npctype = iGlobalNpcType,}
    -- 前端没有存初始信息，reset必须由后端填充
    local oNpc = global.oNpcMgr:GetGlobalNpc(iGlobalNpcType)
    if not oNpc then
        return nil
    end
    mNetInfo.figure = mInfo.figure or oNpc:GetFigureId()
    mNetInfo.title = mInfo.title or oNpc:GetTitle()
    mNetInfo.reset = iReset
    -- local net = require "base.net"
    -- mNetInfo = net.Mask("GlobalNpcAppearence", mNetInfo)
    return mNetInfo
end

function CPlayerVisualMgr:PackMyGlobalNpcs(iGlobalNpcType)
    local lData = {}
    if iGlobalNpcType then
        local mPackData = self:PackMyGlobalNpcInfo(iGlobalNpcType)
        if mPackData then
            table.insert(lData, mPackData)
        end
    else
        for iGloId, mInfo in pairs(self.m_mCustomGlobalNpcs) do
            local mPackData = self:PackMyGlobalNpcInfo(iGloId)
            if mPackData then
                table.insert(lData, mPackData)
            end
        end
    end
    return lData
end

function CPlayerVisualMgr:SyncMyGlobalNpc(oPlayer, iGlobalNpcType)
    local lData = self:PackMyGlobalNpcs(iGlobalNpcType)
    local mNet = {
        npc_appears = lData,
    }
    oPlayer:Send("GS2CChangeVisibility", mNet)
end

function CPlayerVisualMgr:HasSeenNpc(npctype)
    return self.m_mSeenNpcs[npctype]
end

function CPlayerVisualMgr:RecSeenNpc(npctype)
    self:Dirty()
    self.m_mSeenNpcs[npctype] = true
end

function CPlayerVisualMgr:PackValueInfo(mInfo)
    if not mInfo then
        return nil
    end
    local mNet = {}
    for k, v in pairs(mInfo) do
        table.insert(mNet, {id = k, value = v})
    end
    if not next(mNet) then
        return nil
    end
    return mNet
end

function CPlayerVisualMgr:SetGhostEye(oPlayer, iOpen)
    if self.m_iGhostEye == iOpen then
        return
    end
    self:Dirty()
    self.m_iGhostEye = iOpen
    local mNet = {open = (iOpen or 0)}
    oPlayer:Send("GS2CSetGhostEye", mNet)
end

function CPlayerVisualMgr:GetGhostEye()
    return self.m_iGhostEye
end

function CPlayerVisualMgr:SetNpcVisible(oPlayer, lNpcTypes, bVisible)
    local mNetVisibles = {}
    local iVisible = bVisible and 1 or 0
    self:Dirty()
    for _,iNpcType in ipairs(lNpcTypes) do
        if self.m_mVisibleNpcs[iNpcType] ~= iVisible then
            mNetVisibles[iNpcType] = iVisible
            self.m_mVisibleNpcs[iNpcType] = iVisible
        end
        -- local mGlobalNpcData = global.oNpcMgr:GetGlobalNpcData(iNpcType)
        -- assert(mGlobalNpcData, string.format("global npc %d nil", iNpcType))
        -- local iDefVisible = mGlobalNpcData.visible or 0
        -- if iDefVisible ~= iVisible then
        --     self.m_mVisibleNpcs[iNpcType] = iVisible
        -- else
        --     self.m_mVisibleNpcs[iNpcType] = nil
        -- end
    end
    if next(mNetVisibles) then
        local mNet = {
            npcs = self:PackValueInfo(mNetVisibles),
        }
        oPlayer:Send("GS2CChangeVisibility", mNet)
    end
end

function CPlayerVisualMgr:GetNpcVisible(oPlayer, iNpcType)
    local iSetVisible = self.m_mVisibleNpcs[iNpcType]
    if iSetVisible then
        return iSetVisible
    end
    local mGlobalNpcData = global.oNpcMgr:GetGlobalNpcData(iNpcType)
    assert(mGlobalNpcData, string.format("global npc %d nil", iNpcType))
    local iDefVisible = mGlobalNpcData.visible
    return iDefVisible
end

function CPlayerVisualMgr:GetSceneEffectVisible(oPlayer, iSEffId)
    local iSetVisible = self.m_mVisibleSceneEffects[iSEffId]
    if iSetVisible then
        return iSetVisible
    end
    local mSceneEffectData = global.oSceneMgr:GetEffectData(iSEffId)
    assert(mSceneEffectData, string.format("scene effect %d nil", iSEffId))
    local iDefVisible = mSceneEffectData.visible or 0
    return iDefVisible
end

function CPlayerVisualMgr:SetSceneEffectVisible(oPlayer, lSceneEffectIds, bVisible)
    local mNetVisibles = {}
    local iVisible = bVisible and 1 or 0
    self:Dirty()
    for _,iSEffId in ipairs(lSceneEffectIds) do
        if self.m_mVisibleSceneEffects[iSEffId] ~= iVisible then
            mNetVisibles[iSEffId] = iVisible
            self.m_mVisibleSceneEffects[iSEffId] = iVisible
        end
        -- local mSceneEffectData = global.oSceneMgr:GetEffectData(iSEffId)
        -- assert(mSceneEffectData, string.format("scene effect %d nil", iSEffId))
        -- local iDefVisible = mSceneEffectData.visible or 0
        -- if iDefVisible ~= iVisible then
        --     self.m_mVisibleSceneEffects[iSEffId] = iVisible
        -- else
        --     self.m_mVisibleSceneEffects[iSEffId] = nil
        -- end
    end
    if next(mNetVisibles) then
        local mNet = {
            scene_effects = self:PackValueInfo(mNetVisibles),
        }
        oPlayer:Send("GS2CChangeVisibility", mNet)
    end
end

function CPlayerActiveCtrl:AddVigor(iVal, sReason)
    local iOldVigor = self:GetData("vigor", 0)
    self:SetData("vigor", math.max(iOldVigor + iVal, 0))
   
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:PropChange("vigor")
    end
    local mLogData = oPlayer and oPlayer:LogData() or {pid=iPid}
    mLogData.vigor_old = iOldVigor
    mLogData.vigor_add = iVal
    mLogData.vigor_now = self:GetData("vigor", 0)
    mLogData.reason = sReason
    record.log_db("money", "vigor", mLogData)
end

function CPlayerActiveCtrl:ValidAddLeaderPoint(sSource, sReason)
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end

    local mLimit = self:GetLimitConfig("leaderpoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("leaderpoint_day_total", 0)
    if iTotal >= mLimit.day_limit then return false end

    local mBase = self:GetLeaderPointBaseConfig(sSource)
    if not mBase then return false end

    local iDayGet = oPlayer.m_oTodayMorning:Query("leaderpoint_day_"..sSource, 0)
    if iDayGet >= mBase.day_limit then return false end

    return true
end

function CPlayerActiveCtrl:RawAddLeaderPoint(sSource, iTeamSize, sReason)
    if not self:ValidAddLeaderPoint(sSource, sReason) then
        return
    end

    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iChat = 1001
    local mBase = self:GetLeaderPointBaseConfig(sSource)
    local iReward = mBase.single_reward
    if iTeamSize < 5 then
        iReward = math.max(1, math.floor(iReward/2))
        iChat = 1002
    end

    local iDayGet = oPlayer.m_oTodayMorning:Query("leaderpoint_day_"..sSource, 0)
    iReward = math.max(0, math.min(mBase.day_limit-iDayGet, iReward))
    if iReward <= 0 then return end

    local mLimit = self:GetLimitConfig("leaderpoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("leaderpoint_day_total", 0)
    local iVal = math.max(0, math.min(mLimit.day_limit-iTotal, iReward))
    if iVal <= 0 then return end

    oPlayer.m_oTodayMorning:Add("leaderpoint_day_"..sSource, iVal)
    local sMsg = global.oToolMgr:GetTextData(iChat, {"moneypoint"})
    sMsg = global.oToolMgr:FormatString(sMsg, {amount=iVal})
    self:AddLeaderPoint(iVal, sReason, {tip=sMsg})
end

function CPlayerActiveCtrl:AddLeaderPoint(iVal, sReason, mArgs)
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLimit = self:GetLimitConfig("leaderpoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("leaderpoint_day_total", 0)
    local iVal = math.max(0, math.min(mLimit.day_limit-iTotal, iVal))
    if iVal <= 0 then return end

    local mLogData = oPlayer:LogData()
    mLogData["leaderpoint_old"] = self:GetData("leaderpoint", 0)
    mLogData["leaderpoint_add"] = iVal
    mLogData["reason"] = sReason

    oPlayer.m_oTodayMorning:Add("leaderpoint_day_total", iVal)
    self:SetData("leaderpoint", self:GetData("leaderpoint", 0)+iVal)
    oPlayer:PropChange("leaderpoint")
    self:Dirty()

    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            local oToolMgr = global.oToolMgr
            sMsg = oToolMgr:GetTextData(1001, {"moneypoint"})
            sMsg = oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg, true)
        oPlayer:NotifyMessage(sMsg)
    end

    mLogData["leaderpoint_now"] = self:GetData("leaderpoint", 0)
    record.log_db("money", "add_leaderpoint", mLogData)
end

function CPlayerActiveCtrl:ValidLeaderPoint(iVal, mArgs)
    assert(iVal > 0, "try cost negative leaderpoint:"..iVal)
    if self:GetData("leaderpoint", 0) >= iVal then
        return true
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or global.oToolMgr:GetTextData(1004, {"moneypoint"})
        global.oNotifyMgr:Notify(pid,sTip)
    end
    return false
end

function CPlayerActiveCtrl:ResumeLeaderPoint(iVal, sReason, mArgs)
    assert(iVal > 0, "try cost negative leaderpoint:"..iVal)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLogData = oPlayer:LogData()
    mLogData["leaderpoint_old"] = self:GetData("leaderpoint", 0)
    mLogData["leaderpoint_sub"] = iVal
    mLogData["reason"] = sReason

    self:SetData("leaderpoint", math.max(0, self:GetData("leaderpoint", 0)-iVal))
    oPlayer:PropChange("leaderpoint")
    mLogData["leaderpoint_now"] = self:GetData("leaderpoint", 0)
    record.log_db("money", "sub_leaderpoint", mLogData)

    if not mArgs.cancel_chat then
        local sMsg = mArgs.chat
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1006, {"moneypoint"})
            sMsg = global.oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1007, {"moneypoint"})
            sMsg = global.oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oNotifyMgr:Notify(iPid,sMsg)
    end
end

function CPlayerActiveCtrl:StatisticsLeaderPointSource()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mLeaderConfig =  res["daobiao"]["moneypoint"]["statistics_leaderpoint"]
    local mRewardInfo = {}
    for iKey, mBase in pairs(mLeaderConfig ) do
        mRewardInfo[iKey]  = 0
        for _, sSource in pairs(mBase.statistics) do
            mRewardInfo[iKey] = mRewardInfo[iKey] + oPlayer.m_oTodayMorning:Query("leaderpoint_day_"..sSource,0)
        end
    end
    local iTotal = oPlayer.m_oTodayMorning:Query("leaderpoint_day_total", 0)
    return iTotal,mRewardInfo
end

function CPlayerActiveCtrl:ValidAddXiayiPoint(sSource, sReason)
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end

    local mLimit = self:GetLimitConfig("xiayipoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("xiayipoint_day_total", 0)
    if iTotal >= mLimit.day_limit then return false end

    local mBase = self:GetXiayiPointBaseConfig(sSource)
    if not mBase then return false end

    local iDayGet = oPlayer.m_oTodayMorning:Query("xiayipoint_day_"..mBase.limit_key, 0)
    if iDayGet >= mBase.day_limit then return false end

    return true
end

function CPlayerActiveCtrl:RawAddXiayiPoint(sSource, sReason, mArgs)
    if not self:ValidAddXiayiPoint(sSource, sReason) then
        return
    end
    local mBase = self:GetXiayiPointBaseConfig(sSource)
    local iReward = mBase.single_reward
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)

    local iDayGet = oPlayer.m_oTodayMorning:Query("xiayipoint_day_"..mBase.limit_key, 0)
    iReward = math.max(0, math.min(mBase.day_limit-iDayGet, iReward))
    if iReward <= 0 then return end

    local mLimit = self:GetLimitConfig("xiayipoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("xiayipoint_day_total", 0)
    iReward = math.max(0, math.min(mLimit.day_limit-iTotal, iReward))
    if iReward <= 0 then return end

    oPlayer.m_oTodayMorning:Add("xiayipoint_day_"..mBase.limit_key, iReward)
    self:AddXiayiPoint(iReward, sReason, mArgs)
end

function CPlayerActiveCtrl:AddXiayiPoint(iVal, sReason, mArgs)
    local iPid = self:GetInfo("pid") 
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLimit = self:GetLimitConfig("xiayipoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("xiayipoint_day_total", 0)
    if not mArgs.force then
        iVal = math.max(0, math.min(mLimit.day_limit-iTotal, iVal))
        if iVal <= 0 then return end
    end

    local mLogData = oPlayer:LogData()
    mLogData["xiayipoint_old"] = self:GetData("xiayipoint", 0)
    mLogData["xiayipoint_add"] = iVal
    mLogData["reason"] = sReason

    oPlayer.m_oTodayMorning:Add("xiayipoint_day_total", iVal)
    self:SetData("xiayipoint", self:GetData("xiayipoint", 0) + iVal)
    oPlayer:PropChange("xiayipoint")


    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            local oToolMgr = global.oToolMgr
            sMsg = oToolMgr:GetTextData(1003, {"moneypoint"})
            sMsg = oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg, true)
        --oPlayer:NotifyMessage(sMsg)
    end
    mLogData["xiayipoint_now"] = self:GetData("xiayipoint", 0)
    record.log_db("money", "add_xiayipoint", mLogData)
end

function CPlayerActiveCtrl:ValidXiayiPoint(iVal, mArgs)
    assert(iVal > 0, "try cost negative xiayipoint:"..iVal)
    if self:GetData("xiayipoint", 0) >= iVal then
        return true
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or global.oToolMgr:GetTextData(1005, {"moneypoint"})
        global.oNotifyMgr:Notify(pid,sTip)
    end
    return false
end

function CPlayerActiveCtrl:ResumeXiayiPoint(iVal, sReason, mArgs)
    assert(iVal > 0, "try cost negative xiayipoint:"..iVal)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLogData = oPlayer:LogData()
    mLogData["xiayipoint_old"] = self:GetData("xiayipoint", 0)
    mLogData["xiayipoint_sub"] = iVal
    mLogData["reason"] = sReason

    self:SetData("xiayipoint", math.max(0, self:GetData("xiayipoint", 0)-iVal))
    oPlayer:PropChange("xiayipoint")
    mLogData["xiayipoint_now"] = self:GetData("xiayipoint", 0)
    record.log_db("money", "sub_xiayipoint", mLogData)

    if not mArgs.cancel_chat then
        local sMsg = mArgs.chat
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1008, {"moneypoint"})
            sMsg = global.oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1009, {"moneypoint"})
            sMsg = global.oToolMgr:FormatString(sMsg, {amount=iVal})
        end
        global.oNotifyMgr:Notify(iPid,sMsg)
    end
end

function CPlayerActiveCtrl:StatisticsXiayiPointSource()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mXiayiConfig =  res["daobiao"]["moneypoint"]["statistics_xiayipoint"]
    local mRewardInfo = {}
    for iKey, mBase in pairs(mXiayiConfig) do
        mRewardInfo[iKey]  = 0
        for _, sSource in pairs(mBase.statistics) do
            mRewardInfo[iKey] = mRewardInfo[iKey] + oPlayer.m_oTodayMorning:Query("xiayipoint_day_"..sSource,0)
        end
    end
    local iTotal = oPlayer.m_oTodayMorning:Query("xiayipoint_day_total", 0)
    return iTotal, mRewardInfo
end

function CPlayerActiveCtrl:RewardSummonPoint(iVal, sReason, mArgs)
    assert(iVal > 0, string.format("%d RewardSummonPoint err %d",self:GetInfo("pid"), iVal))
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iPoint = self:GetData("summonpoint", 0)
    self:SetData("summonpoint", iPoint + iVal)
    oPlayer:PropChange("summonpoint")    

    mArgs = mArgs or {}
    local sMsg = global.oToolMgr:FormatColorString("你获得了#amount合成积分", {amount = iVal})
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
    local mLogData = oPlayer:LogData()
    mLogData["summonpoint_old"] = iPoint
    mLogData["summonpoint_add"] = iVal
    mLogData["summonpoint_now"] = iPoint + iVal
    mLogData["reason"] = sReason
    record.log_db("money", "add_summonpoint", mLogData)
end

function CPlayerActiveCtrl:ValidSummonPoint(iVal, mArgs)
    assert(iVal > 0, string.format("%d ValidSummonPoint err %d",self:GetInfo("pid"), iVal))
    if self:GetData("summonpoint", 0) >= iVal then
        return true
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        global.oNotifyMgr:Notify(self:GetInfo("pid"), "合成积分不足")
    end
    return false
end

function CPlayerActiveCtrl:ResumeSummonPoint(iVal, sReason, mArgs)
    assert(iVal>0, string.format("%d ResumeSummonPoint err %d",self:GetInfo("pid"), iVal))
    local iPoint = self:GetData("summonpoint", 0)
    assert((iPoint - iVal)>=0, string.format("%d ResumeSummonPoint err2 %d",self:GetInfo("pid"),iVal))
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    self:SetData("summonpoint", iPoint - iVal)
    oPlayer:PropChange("summonpoint")    

    mArgs = mArgs or {}
    local sMsg = global.oToolMgr:FormatColorString("你消耗了#amount合成积分", {amount = iVal})
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
    if not mArgs.cancel_tip then
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
    local mLogData = oPlayer:LogData()
    mLogData["summonpoint_old"] = iPoint
    mLogData["summonpoint_sub"] = iVal
    mLogData["summonpoint_now"] = iPoint - iVal
    mLogData["reason"] = sReason
    record.log_db("money", "sub_summonpoint", mLogData)
end

function CPlayerActiveCtrl:ValidEnergy(iVal, mArgs)
    assert(iVal>0, string.format("valid energy meed val(%s) > 0", iVal))
    if self:GetData("energy", 0) >= iVal then return true end

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        global.oNotifyMgr:Notify(self:GetInfo("pid"), "活力不足")
    end
    return false
end

function CPlayerActiveCtrl:RewardEnergy(iVal, sReason, mArgs)
    assert(iVal>0, string.format("reward energy meed val(%s) > 0", iVal))
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end

    local iEnergy = self:GetData("energy", 0)
    local iMax = oPlayer:GetMaxEnergy()
    local iLimitMax = oPlayer:GetMaxLimitEnergy()
    if iEnergy >= iLimitMax then
        local sText = global.oToolMgr:GetTextData(3012)
        oPlayer:NotifyMessage(sText)
        return
    end
    
    iVal = math.min(iVal, iLimitMax - iEnergy)
    iEnergy = iEnergy + iVal
    self:SetData("energy", iEnergy)
    oPlayer:PropChange("energy")
    if iEnergy>= iMax then
        local sText = global.oToolMgr:GetTextData(3011)
        oPlayer:NotifyMessage(sText)
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(string.format("获得#G%s#n活力",iVal))
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, string.format("获得#G%s#n活力",iVal))
    end
end

function CPlayerActiveCtrl:ResumeEnergy(iVal, sReason, mArgs)
    assert(iVal>0, string.format("resume energy meed val(%s) > 0", iVal))
    local iEnergy = self:GetData("energy", 0)
    assert(iEnergy>=iVal, string.format("resume energy energy(%s) less val(%s)", iEnergy, iVal))
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end

    local iEnergy = self:GetData("energy", 0)
    self:SetData("energy", math.max(iEnergy - iVal, 0))
    oPlayer:PropChange("energy")

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(string.format("消耗#G%s#n活力",iVal))
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, string.format("消耗#G%s#n活力",iVal))
    end
end

function CPlayerActiveCtrl:ValidStoryPoint(iVal, mArgs)
    assert(iVal>0, string.format("valid storypoint meed val(%s) > 0", iVal))
    if self:GetData("storypoint", 0) >= iVal then return true end

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        global.oNotifyMgr:Notify(self:GetInfo("pid"), "剧情技能点不足")
    end
    return false
end

function CPlayerActiveCtrl:CheckResetEnergy(oPlayer)
    local iCurDay = get_morningdayno()
    local iOfflineDay = get_morningdayno(self:GetDisconnectTime())
    if iCurDay~=iOfflineDay then
        self:ReSetEnergy(oPlayer)
    end
end

function CPlayerActiveCtrl:ReSetEnergy(oPlayer)
    local iEnergy = oPlayer:GetEnergy()
    local iMaxEnergy = oPlayer:GetMaxEnergy()
    iEnergy = math.min(iEnergy,iMaxEnergy)
    self:SetData("energy",iEnergy)
    oPlayer:PropChange("energy")
end

function CPlayerActiveCtrl:RewardStoryPoint(iVal, sReason, mArgs)
    assert(iVal>0, string.format("reward storypoint val(%s) > 0", iVal))
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end

    local iPoint = self:GetData("storypoint", 0)
    iPoint = iPoint + iVal
    self:SetData("storypoint", iPoint)
    oPlayer:PropChange("storypoint")

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(string.format("获得#G%s#n剧情技能点",iVal))
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, string.format("获得#G%s#n剧情技能点",iVal))
    end
    local mLogData = oPlayer:LogData()
    mLogData.storypoint_add = iVal
    mLogData.storypoint_cur = iPoint
    mLogData.reason = sReason
    record.log_db("money", "add_storypoint", mLogData)
end

function CPlayerActiveCtrl:ResumeStoryPoint(iVal, sReason, mArgs)
    assert(iVal>0, string.format("resume energy meed val(%s) > 0", iVal))
    local iPoint = self:GetData("storypoint", 0)
    assert(iPoint>=iVal, string.format("resume storypoint point(%s) less val(%s)", iPoint, iVal))
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then return end
    iPoint = iPoint - iVal
    self:SetData("storypoint", iPoint)
    oPlayer:PropChange("storypoint")

    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        oPlayer:NotifyMessage(string.format("消耗#G%s#n剧情技能点",iVal))
    end
    if not mArgs.cancel_chat then
        global.oChatMgr:HandleMsgChat(oPlayer, string.format("消耗#G%s#n剧情技能点",iVal))
    end
    local mLogData = oPlayer:LogData()
    mLogData.storypoint_sub = iVal
    mLogData.storypoint_cur = iPoint
    mLogData.reason = sReason
    record.log_db("money", "sub_storypoint", mLogData)
end

function CPlayerActiveCtrl:GetLeaderPointBaseConfig(sKey)
    return res["daobiao"]["moneypoint"]["base_leaderpoint_config"][sKey]
end

function CPlayerActiveCtrl:GetLimitConfig(sKey)
    return res["daobiao"]["moneypoint"]["limit_config"][sKey]
end

function CPlayerActiveCtrl:GetXiayiPointBaseConfig(sKey)
    return res["daobiao"]["moneypoint"]["base_xiayipoint_config"][sKey]
end

function CPlayerActiveCtrl:GetChumoPointBaseConfig(sKey)
    return res["daobiao"]["moneypoint"]["base_chumopoint_config"][sKey]
end

function CPlayerActiveCtrl:SetSceneShareObj(oShareObj)
    self:ClearSceneShareObj()
    self.m_oSceneShareObj = CScenePlayerShareObj:New()
    self.m_oSceneShareObj:Init(oShareObj)
end

function CPlayerActiveCtrl:ClearSceneShareObj()
    if self.m_oSceneShareObj then
        baseobj_safe_release(self.m_oSceneShareObj)
        self.m_oSceneShareObj = nil
    end
end

function CPlayerActiveCtrl:ValidAddChumoPoint(sSource, sReason)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end

    local mBase = self:GetChumoPointBaseConfig(sSource)
    if not mBase then return false end

    local mLimit = self:GetLimitConfig("chumopoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("chumopoint_day_total", 0)
    if iTotal >= mLimit.day_limit then return false end

    local iDayGet = oPlayer.m_oTodayMorning:Query("chumopoint_day_" .. sSource, 0)
    if iDayGet >= mBase.day_limit then return false end

    return true
end

function CPlayerActiveCtrl:RawAddChumoPoint(sSource, sReason, mArgs)
    if not self:ValidAddChumoPoint(sSource, sReason) then
        return
    end

    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return false end

    local mBase = self:GetChumoPointBaseConfig(sSource)
    local iReward = mBase.single_reward
    local iDayGet = oPlayer.m_oTodayMorning:Query("chumopoint_day_" .. sSource, 0)
    iReward = math.max(0, math.min(mBase.day_limit - iDayGet, iReward))
    if iReward <= 0 then return end

    local mLimit = self:GetLimitConfig("chumopoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("chumopoint_day_total", 0)
    iReward = math.max(0, math.min(mLimit.day_limit - iTotal, iReward))
    if iReward <= 0 then return end

    oPlayer.m_oTodayMorning:Add("chumopoint_day_" .. sSource, iReward)
    self:AddChumoPoint(iReward, sReason, mArgs)
 end

function CPlayerActiveCtrl:AddChumoPoint(iVal, sReason, mArgs)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLimit = self:GetLimitConfig("chumopoint")
    local iTotal = oPlayer.m_oTodayMorning:Query("chumopoint_day_total", 0)
    if not mArgs.force then
        iVal = math.max(0, math.min(mLimit.day_limit - iTotal, iVal))
        if iVal <= 0 then return end
    end

    local mLogData = oPlayer:LogData()
    mLogData["chumopoint_old"] = self:GetData("chumopoint", 0)
    mLogData["chumopoint_add"] = iVal
    mLogData["reason"] = sReason

    oPlayer.m_oTodayMorning:Add("chumopoint_day_total", iVal)
    self:SetData("chumopoint", self:GetData("chumopoint", 0) + iVal)
    oPlayer:PropChange("chumopoint")

    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            local oToolMgr = global.oToolMgr
            sMsg = oToolMgr:GetTextData(1012, {"moneypoint"})
            sMsg = oToolMgr:FormatColorString(sMsg, {amount = iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg, true)
    end

    mLogData["chumopoint_now"] = self:GetData("chumopoint", 0)
    record.log_db("money", "add_chumopoint", mLogData)
end

function CPlayerActiveCtrl:ValidChumoPoint(iVal, mArgs)
    assert(iVal > 0 ,"try cost negative chumopoint:" .. iVal)
    if self:GetData("chumopoint", 0) >= iVal then
        return true
    end
    mArgs = mArgs or {}
    if not mArgs.cancel_tip then
        local sTip = mArgs.tip or global.oToolMgr:GetTextData(1015, {"moneypoint"})
        global.oNotifyMgr:Notify(pid, sTip)
    end
    return false
end

function CPlayerActiveCtrl:ResumeChumoPoint(iVal, sReason, mArgs)
    assert(iVal > 0, "try cost negative chumopoint:" .. iVal)
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    mArgs = mArgs or {}
    local mLogData = oPlayer:LogData()
    mLogData["chumopoint_old"] = self:GetData("chumopoint", 0)
    mLogData["chumopoint_sub"] = iVal
    mLogData["reason"] = sReason

    self:SetData("chumopoint", math.max(0, self:GetData("chumopoint", 0) - iVal))
    oPlayer:PropChange("chumopoint")
    mLogData["chumopoint_now"] = self:GetData("chumopoint", 0)
    record.log_db("money", "sub_chumopoint", mLogData)

    if not mArgs.cancel_chat then
        local sMsg = mArgs.chat
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1013, {"moneypoint"})
            sMsg = global.oToolMgr:FormatColorString(sMsg, {amount = iVal})
        end
        global.oChatMgr:HandleMsgChat(oPlayer,sMsg)
    end
    if not mArgs.cancel_tip then
        local sMsg = mArgs.tip
        if not sMsg then
            sMsg = global.oToolMgr:GetTextData(1014, { "moneypoint"})
            sMsg = global.oToolMgr:FormatColorString(sMsg, {amount = iVal})
        end
        global.oNotifyMgr:Notify(iPid, sMsg)
    end
end

function CPlayerActiveCtrl:StatisticsChumoPointSource()
    local iPid = self:GetInfo("pid")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    local mChumoConfig = res["daobiao"]["moneypoint"]["statistics_chumopoint"]
    local mRewardInfo = {}
    for iKey, mBase in pairs(mChumoConfig) do
        mRewardInfo[iKey] = 0
        for _, sSource in pairs(mBase.statistics) do
            mRewardInfo[iKey] = mRewardInfo[iKey] + oPlayer.m_oTodayMorning:Query("chumopoint_day_" .. sSource, 0)
        end
    end
    local iTotal = oPlayer.m_oTodayMorning:Query("chumopoint_day_total", 0)
    return iTotal, mRewardInfo
end

CScenePlayerShareObj = {}
CScenePlayerShareObj.__index = CScenePlayerShareObj
inherit(CScenePlayerShareObj, shareobj.CShareReader)

function CScenePlayerShareObj:New()
    local o = super(CScenePlayerShareObj).New(self)
    o.m_mPos = {}
    return o
end

function CScenePlayerShareObj:Unpack(m)
    self.m_mPos = m.pos_info
end

function CScenePlayerShareObj:GetNowPos()
    self:Update()
    return self.m_mPos
end
