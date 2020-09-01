--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))


function NewBoonMgr(...)
    return COrgBoonMgr:New(...)
end


COrgBoonMgr = {}
COrgBoonMgr.__index = COrgBoonMgr
inherit(COrgBoonMgr, datactrl.CDataCtrl)

-- 简单的福利相关
function COrgBoonMgr:New(orgid)
    local o = super(COrgBoonMgr).New(self, {orgid = orgid})
    o:Init()
    return o
end

function COrgBoonMgr:Init()
    self.m_mWeekMemCash = {}
    self.m_mWeekMemHuoYue = {}

    --　计算奖励
    self.m_iWeekTime = 0
    self.m_iCashLevel = 0                                    -- 金库等级   
    self.m_iLeftCash = 0                                      -- 剩余资金
    self.m_iHouseLevel = 0
    self.m_iDayOrgLevel = 0 
    self.m_iWeekOrgLevel = 0                             -- 帮派等级
    self.m_iWeekBoom = 0                                -- 帮派繁荣度
    self.m_iHuoYue = 0                                        -- 上周活跃
    self.m_mMemCash = {}                                  -- 上周成员增加的资金 
    self.m_mMemHuoYue = {}                             -- huoyue 
    self.m_mMemPos = {}                                    -- 玩家上周的管理职位
    self.m_lRecePosBonus = {}
end

function COrgBoonMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgBoonMgr:Load(mData)
    if not mData then return end

    for iPid, iVal in pairs(mData.week_mem_cash) do
        iPid = tonumber(iPid)
        self.m_mWeekMemCash[iPid] = iVal   
    end

    for iPid, iVal in pairs(mData.week_mem_huoyue) do
        iPid = tonumber(iPid)
        self.m_mWeekMemHuoYue[iPid] = iVal
    end

    self.m_iWeekTime = mData.week_time or 0
    self.m_iCashLevel = mData.cash_level or 0
    self.m_iLeftCash = mData.left_cash or 0
    self.m_iHouseLevel = mData.house_level or 0
    self.m_iDayOrgLevel = mData.day_org_level 
    self.m_iWeekOrgLevel = mData.week_org_level
    self.m_iWeekBoom = mData.week_boom or 0
    self.m_iHuoYue = mData.huo_yue

    for iPid, iVal in pairs(mData.mem_cash) do
        iPid = tonumber(iPid)
        self.m_mMemCash[iPid] = iVal   
    end

    for iPid, iVal in pairs(mData.mem_huoyue or {}) do
        iPid = tonumber(iPid)
        self.m_mMemHuoYue[iPid] = iVal
    end

    for iPid, iPos in pairs(mData.mem_pos) do
        iPid = tonumber(iPid)
        self.m_mMemPos[iPid] = iPos
    end
    
    self.m_lRecePosBonus = mData.rece_pos_bonus
end

function COrgBoonMgr:Save()
    local mData = {}

    local mCash = {}
    for iPid, iVal in pairs(self.m_mWeekMemCash) do
        mCash[db_key(iPid)] = iVal
    end
    mData.week_mem_cash = mCash

    local mWeekHuoYue = {}
    for iPid, iVal in pairs(self.m_mWeekMemCash) do
        mWeekHuoYue[db_key(iPid)] = iVal
    end
    mData.week_mem_huoyue = mWeekHuoYue

    mData.week_time = self.m_iWeekTime
    mData.cash_level = self.m_iCashLevel
    mData.left_cash = self.m_iLeftCash
    mData.house_level = self.m_iHouseLevel
    mData.day_org_level = self.m_iDayOrgLevel
    mData.week_org_level = self.m_iWeekOrgLevel
    mData.huo_yue = self.m_iHuoYue
    mData.week_boom = self.m_iWeekBoom

    local mMemCash = {}
    for iPid, iVal in pairs(self.m_mMemCash) do
        mMemCash[db_key(iPid)] = iVal
    end
    mData.mem_cash = mMemCash

    local mMemHuoYue = {}
    for iPid, iVal in pairs(self.m_mMemCash) do
        mMemHuoYue[db_key(iPid)] = iVal
    end
    mData.mem_huoyue = mMemHuoYue

    local mMemPos = {}
    for iPid, iPos in pairs(self.m_mMemPos) do
        mMemPos[db_key(iPid)] = iPos
    end
    mData.mem_pos = mMemPos

    mData.rece_pos_bonus = self.m_lRecePosBonus
    return mData
end

function COrgBoonMgr:AddCash(iPid, iVal)
    if not iPid or iVal <= 0 then return end

    local iCnt = self.m_mWeekMemCash[iPid] or 0
    self.m_mWeekMemCash[iPid] = iVal + iCnt
    self:Dirty()
end

function COrgBoonMgr:SetDayOrgLevel(iLv)
    self.m_iDayOrgLevel = iLv
    self:Dirty()
end

function COrgBoonMgr:AddHuoYue(iPid, iVal)
    local iCnt = self.m_mWeekMemHuoYue[iPid] or 0
    self.m_mWeekMemHuoYue[iPid] = iVal + iCnt
    self:Dirty()
end

function COrgBoonMgr:WeekMaintain()
    local oOrg = self:GetOrg()

    self:ClearWeekData()
    self.m_iCashLevel = oOrg.m_oBuildMgr:GetBuildCashLevel()
    self.m_iWeekOrgLevel = oOrg:GetLevel()
    self.m_iWeekBoom = oOrg:GetBoom()
    self.m_iHuoYue = oOrg.m_oBaseMgr:GetWeekHuoYue()
    self.m_iLeftCash = oOrg:GetCash()
    self.m_iHouseLevel = oOrg.m_oBuildMgr:GetBuildHouseLevel()

    local mPos = {}
    local lPos = {orgdefines.ORG_POSITION.LEADER,
                        orgdefines.ORG_POSITION.DEPUTY,
                        orgdefines.ORG_POSITION.ELDER}

    for iPos, lPid in pairs(oOrg.m_oMemberMgr:GetMemPosMap()) do
        if table_in_list(lPos, iPos) then
            for _, iPid in pairs(lPid) do
                mPos[iPid] = iPos
            end
        end
    end
    self.m_mMemPos = mPos
    self:Dirty()
end

function COrgBoonMgr:ClearWeekData()
    self.m_iCashLevel = 0
    self.m_iWeekOrgLevel = 0
    self.m_iLeftCash = 0
    self.m_iHouseLevel = 0
    self.m_iHuoYue = 0
    self.m_mMemCash = self.m_mWeekMemCash
    self.m_mMemHuoYue = self.m_mWeekMemHuoYue
    self.m_mMemPos = {}
    self.m_lRecePosBonus = {}
    self.m_iWeekTime = get_time()

    self.m_mWeekMemCash = {}
    self.m_mWeekMemHuoYue = {}
end

function COrgBoonMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 0 then
        self:NewHour0(mNow)
    end
 
    if iHour == 5 then
        self:NewHour5(mNow)
    end
end

function COrgBoonMgr:NewHour0(mNow)
end

function COrgBoonMgr:NewHour5(mNow)
end

function COrgBoonMgr:GS2CGetBoonInfo(oPlayer)
    local mNet = {} 
    mNet.sign_status = self:GetSignStatus(oPlayer)
    
    local oOrg = self:GetOrg()
    local iGoldCoin, iGold, iSilver, iOffer = self:GetBonusReward(oPlayer)
    mNet.bonus_status = self:GetBonusStatus(oPlayer:GetPid())
    mNet.bonus_reward = {0, iGoldCoin, iGold, iSilver, iOffer}

    local iPos = self.m_mMemPos[oPlayer:GetPid()]
    if iPos then
        mNet.pos_status = self:GetPosBonusStatus(oPlayer:GetPid())
        mNet.position = iPos
        mNet.pos_reward = {0, self:GetPosBonusCoin(oPlayer), 0, 0, 0}
    end

    local mRedPoint = {}
    mRedPoint.sign_status = mNet.sign_status
    mRedPoint.bonus_status = mNet.bonus_status
    mRedPoint.pos_status = mNet.pos_status

    oPlayer:Send("GS2CGetBoonInfo", mNet)
    oPlayer:Send("GS2COrgFlag", oOrg:PackOrgFlag(mRedPoint))
end

function COrgBoonMgr:GetSignSilver(oPlayer)
     -- 银币奖励计算方式：帮派等级固定值（可配置）*玩家昨日活跃比（昨日实际活跃值/100）+1000
     -- TODO 看是否需要转成配置
     local sFormula = global.oOrgMgr:GetOtherConfig("sign_sliver")
     local oOrg = self:GetOrg()
     local iRatio = (100 + oOrg:GetBoonSignRatio()) / 100
     local oWorldMgr = global.oWorldMgr
     local iVal = formula_string(sFormula, {SLV=oPlayer:GetServerGrade(), huoyue=oPlayer:GetLastDayHuoYue()})
     return math.floor(iVal * iRatio)
end

function COrgBoonMgr:DoSign(oPlayer, sMsg)
    if self:HasSign(oPlayer) then return end

    local mLog = oPlayer:LogData()
    mLog["org_id"] = self:GetInfo("orgid")
    mLog["old_silver"] = oPlayer:GetSilver()

    local iVal = self:GetSignSilver(oPlayer)
    oPlayer.m_oTodayMorning:Set("org_sign", 1)
    oPlayer:RewardSilver(iVal, "帮派签到")

    mLog["now_silver"] = oPlayer:GetSilver()
    record.log_db("org", "org_sign", mLog)

    local oOrgMgr = global.oOrgMgr
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1099))
    oOrgMgr:SendMsg2Org(self:GetInfo("orgid"), sMsg, oPlayer)
    self:GS2CGetBoonInfo(oPlayer)
end

function COrgBoonMgr:GetSignStatus(oPlayer)
    if self:HasSign(oPlayer) then return 1 end

    return 0
end

function COrgBoonMgr:HasSign(oPlayer)
    return oPlayer.m_oTodayMorning:Query("org_sign") == 1 
end

function COrgBoonMgr:GetBonusReward(oPlayer)
    local oOrg = self:GetOrg()
    local iRatio = (100 + oOrg:GetBoonBousRatio()) / 100

    local iGoldCoin, iGold, iSilver, iOffer = 0, 0, 0, 0
    local iCash = self.m_mMemCash[oPlayer:GetPid()] or 0
    local sGoldFormula = global.oOrgMgr:GetOtherConfig("bonus_gold")
    iGold = formula_string(sGoldFormula, {cash = iCash}) * iRatio   

    local sSliverFormula = global.oOrgMgr:GetOtherConfig("bonus_sliver")
    iSilver = formula_string(sSliverFormula, {cash = iCash}) * iRatio
    return math.floor(iGoldCoin), math.floor(iGold), math.floor(iSilver), math.floor(iOffer)
end

function COrgBoonMgr:ReceiveBonus(oPlayer)
    if self:GetBonusStatus(oPlayer:GetPid()) ~= 1 then return end

    local mLog = oPlayer:LogData()
    mLog["org_id"] = self:GetInfo("orgid") 
    mLog["old_silver"] = oPlayer:GetSilver()
    mLog["old_gold"] = oPlayer:GetGold()
    mLog["old_goldcoin"] = oPlayer:GetGoldCoin()

    local iGoldCoin, iGold, iSilver, iOffer = self:GetBonusReward(oPlayer)
    oPlayer.m_oWeekMorning:Set("org_bonus", 1)
    if iSilver > 0 then oPlayer:RewardSilver(iSilver, "帮派分红") end
        
    if iOffer > 0 then oPlayer:AddOrgOffer(iOffer, "帮派分红") end

    if iGold > 0 then oPlayer:RewardGold(iGold, "帮派分红") end

    if iGoldCoin > 0 then oPlayer:RewardGoldCoin(iGoldCoin, "帮派分红") end

    mLog["now_silver"] = oPlayer:GetSilver()
    mLog["now_gold"] = oPlayer:GetGold()
    mLog["now_goldcoin"] = oPlayer:GetGoldCoin()    
    record.log_db("org", "receive_bonus", mLog)

    local oOrgMgr = global.oOrgMgr
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1110))
    self:GS2CGetBoonInfo(oPlayer)
end

function COrgBoonMgr:GetBonusStatus(iPid)
    -- if self.m_iWeekTime <= 0 then return 0 end

    local oOrg = self:GetOrg()
    if oOrg:IsXueTu(iPid) then return 0 end
    -- local oMember = oOrg:GetMember(iPid) or oOrg:GetXueTu(iPid) 
    -- if not oMember or oMember:GetJoinTime() > self.m_iWeekTime then return 0 end

    if self:HasReceiveBonus(iPid) then
        return 2 
    end
    return 1
end

function COrgBoonMgr:HasReceiveBonus(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer and oPlayer.m_oWeekMorning:Query("org_bonus", 0) == 0 then
        return false
    end
    return true
end

function COrgBoonMgr:GetPosBonusCoin(oPlayer)
    local iGoldCoin = 0

    local oOrg = self:GetOrg()
    local iPos = self.m_mMemPos[oPlayer:GetPid()]
    local oLv = self.m_iWeekOrgLevel
    local iBoom = self.m_iWeekBoom or 0
    local iCash = self.m_mMemCash[oPlayer:GetPid()] or 0
    if iPos == orgdefines.ORG_POSITION.LEADER then
        local sFormula = global.oOrgMgr:GetOtherConfig("leader_bonus")
        iGoldCoin = formula_string(sFormula, {org_lv = oLv, boom = iBoom})
    elseif iPos == orgdefines.ORG_POSITION.DEPUTY then
        local sFormula = global.oOrgMgr:GetOtherConfig("deputy_bonus")
        iGoldCoin = formula_string(sFormula, {org_lv = oLv, boom = iBoom})
    elseif iPos == orgdefines.ORG_POSITION.ELDER then
        local sFormula = global.oOrgMgr:GetOtherConfig("elder_bonus")
        iGoldCoin = formula_string(sFormula, {org_lv = oLv, boom = iBoom})
    end

    local iRatio = (oOrg:GetBoonPosRatio() + 100) / 100
    iGoldCoin = math.floor(iGoldCoin * iRatio)
    return math.max(iGoldCoin, 1)
end

function COrgBoonMgr:GetPosBonusStatus(iPid)
    if self.m_iWeekTime <= 0 then return 0 end
    if not self.m_mMemPos[iPid] then return 0 end

    local oOrg = self:GetOrg()
    local oMember = oOrg:GetMember(iPid)
    if not oMember or oMember:GetJoinTime() > self.m_iWeekTime then return 0 end

    if self:HasRecePosBonus(iPid) then
        return 2
    end
    return 1
end

function COrgBoonMgr:ReceivePosBonus(oPlayer)
    local iPos = self.m_mMemPos[oPlayer:GetPid()]
    if not iPos then return end

    if self:GetPosBonusStatus(oPlayer:GetPid()) ~= 1 then return end
    self:SetRecePosBonus(oPlayer:GetPid())
    
    local mLog = oPlayer:LogData()
    mLog["org_id"] = self:GetInfo("orgid")
    mLog["old_goldcoin"] = oPlayer:GetGoldCoin()

    local iGoldCoin = self:GetPosBonusCoin(oPlayer)
    if iGoldCoin > 0 then
        oPlayer:RewardGoldCoin(iGoldCoin, "职位奖励")
    end

    mLog["now_goldcoin"] = oPlayer:GetGoldCoin()
    record.log_db("org", "receive_pos_bonus", mLog)

    local oOrgMgr = global.oOrgMgr
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1110))
    self:GS2CGetBoonInfo(oPlayer) 
end

function COrgBoonMgr:SetRecePosBonus(iPid)
    table.insert(self.m_lRecePosBonus, iPid)
    self:Dirty()
end

function COrgBoonMgr:HasRecePosBonus(iPid)
    return table_in_list(self.m_lRecePosBonus, iPid)
end



