local global = require "global"
local record = require "public.record"
local res = require "base.res"

function NewOnlineOffsetMgr(...)
    return COnlineOffsetMgr:New(...)
end

function Test(oPlayer)
    local mLogData = oPlayer:LogData()
    record.log_db("gm", "fixbug", mLogData)
end

function ReturnPartnerSilver(oPlayer)
    local mPartnerEquipCost = res["daobiao"]["partner"]["partner_equip_strength_cost"]
    local mAllPartners = oPlayer.m_oPartnerCtrl:GetAllPartner()
    local iTotal = 0
    local mInfo = {}
    for iPartner, oPartner in pairs(mAllPartners) do
        for iPos, oEquip in pairs(oPartner.m_oEquipCtrl.m_mPos2Equip) do
            local iStrengthLevel = oEquip:GetStrengthLevel()
            local iNeed = 0
            for i = 1, iStrengthLevel do
                local iNeedSilver = mPartnerEquipCost[i] and mPartnerEquipCost[i].strength_silver or 0
                local iCost = math.floor(iNeedSilver / math.min(0.3+math.floor(i/10)*0.1, 1) * math.max(0.7-math.floor(i/10)*0.1, 0))
                iNeed = iNeed + iCost
            end
            iTotal = iTotal + iNeed
            if not mInfo[oPartner:GetSID()] then
                mInfo[oPartner:GetSID()] = {}
            end
            mInfo[oPartner:GetSID()][iPos] = {
                sliver = iNeed,
                level = iStrengthLevel,
            }
        end
    end
    if iTotal > 0 then
        local mMail, sName = global.oMailMgr:GetMailInfo(9008)
        local mReward = {silver = iTotal}
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mMail, mReward)
        mInfo.total = iTotal
    end

    local mLogData = oPlayer:LogData()
    mLogData.info = mInfo
    record.log_db("gm", "fixbug", mLogData)
end

function ResetGradeGiftMark(oPlayer)
    do return end
end

function FixMailBugKaifudianli(oPlayer)
    if tonumber(get_server_id()) ~= 10002 then return end
    local mLogData = oPlayer:LogData()
    local oMailBox = oPlayer:GetMailBox()
    for _, sMailName in ipairs({"冲级榜冠军", "冲级榜亚军", "冲级榜季军", "冲级榜前十", "冲级榜前一百",}) do
        local iRet = 0
        local lDelete = {}
        for iMail, oMail in pairs(oMailBox.m_mMailIDs) do
            if oMail:GetData("title") == sMailName then
                table.insert(lDelete, iMail)
            end
        end
        for _, iMail in ipairs(lDelete) do
            oMailBox:DelMail(iMail)
        end
        global.oMailMgr:OnLogin(oPlayer)
        mLogData.info = lDelete
    end

    record.log_db("gm", "fixbug", mLogData)
end

function ResetGradeGiftMark1(oPlayer)
    local net = require "base.net"
    if oPlayer:Query("grade_gift2", 0) <= 0 then
        return
    end
    local mGradePairs = {
        {65, 63}, {70, 66}, {75, 68}, {80, 70},
    }
    local lLogKey = {}
    for i, mPair in ipairs(mGradePairs) do
        local iOld, iNew = table.unpack(mPair)
        local sOldKey = "grade_gift2_"..iOld
        local sNewKey = "grade_gift2_"..iNew
        local iOldVal = oPlayer:Query(sOldKey)
        if iOldVal then
            oPlayer:Set(sOldKey, nil)
            oPlayer:Set(sNewKey, iOldVal)
            table.insert(lLogKey, sNewKey)
        end
    end
    if #lLogKey > 0 then
        local oHuodong = global.oHuodongMgr:GetHuodong("charge")
        local mNet = {
            gift_grade_list = oHuodong:PackGradeGift(oPlayer)
        }
        mNet = net.Mask("GS2CChargeGiftInfo", mNet)
        oPlayer:Send("GS2CChargeGiftInfo", mNet)

        local mLogData = oPlayer:LogData()
        mLogData.info = lLogKey
        record.log_db("gm", "fixbug", mLogData)
    end
end

function ReturnItem10181(oPlayer)
    if oPlayer:Query("exchange_4001", 0) > 0 then
        local mGiveInfo = {sid = 10181, amount = 50}
        local mMail, sName = global.oMailMgr:GetMailInfo(9009)
        local oItem = global.oItemLoader:Create(mGiveInfo.sid)
        oItem:SetAmount(mGiveInfo.amount)
        local mReward = { items = {oItem}}
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mMail, mReward)

        local mLogData = oPlayer:LogData()
        mLogData.info = mGiveInfo
        record.log_db("gm", "fixbug", mLogData)
    end
end

function CalCharge(oPlayer)
    local oCharge = global.oHuodongMgr:GetHuodong("charge")
    if oCharge then
        oCharge:CalAllCharge(oPlayer)
        oCharge:CalStoreCharge(oPlayer)
    end
end

function ReturnItem11187(oPlayer)
    if not oPlayer then return end
    if not oPlayer.m_oRideCtrl then return end
    local iGrade = oPlayer.m_oRideCtrl:GetGrade()
    if not iGrade then return end
    if iGrade > 0 then
        local mMail, sName = global.oMailMgr:GetMailInfo(9010)
        local oItem = global.oItemLoader:Create(11187)
        oItem:SetAmount(iGrade)
        local mReward = {items = {oItem}}
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mMail, mReward)

        local mLogData = oPlayer:LogData()
        mLogData.info = { sid = 11187, amount = iGrade}
        record.log_db("gm", "fixbug", mLogData)
    end
end

function ReturnItem10163(oPlayer)
    if not oPlayer then return end
    if not oPlayer.m_oRideCtrl then return end
    local iLevel = oPlayer.m_oWingCtrl:GetLevel()
    if not iLevel then return end
    local lReturnAmount = {[1] = 5, [2] = 12, [3] = 24, [4] = 47, [5] = 92}
    if iLevel > 0 and lReturnAmount[iLevel] then
        local mMail, sName = global.oMailMgr:GetMailInfo(9011)
        local oItem = global.oItemLoader:Create(10163)
        oItem:SetAmount(lReturnAmount[iLevel])
        local mReward = {items = {oItem}}
        global.oMailMgr:SendMailNew(0, sName, oPlayer:GetPid(), mMail, mReward)

        local mLogData = oPlayer:LogData()
        mLogData.info = {sid = 10163, amount = lReturnAmount[iLevel]}
        record.log_db("gm", "fixbug", mLogData)
    end
end

function CheckPointPlan(oPlayer)
    local iGrade = oPlayer:GetGrade()
    if iGrade <= 59 or iGrade > 65 then return end

    local mWashPoint = res["daobiao"]["washpoint"]
    local lPlanID = table_key_list(mWashPoint)
    table.sort(lPlanID)
    local lPointPlan = oPlayer.m_oBaseCtrl:GetData("point_plan")
    for _, iPlan in ipairs(lPlanID) do
        if iGrade >= mWashPoint[iPlan].unlock_lev then
            local mPlan = lPointPlan[iPlan]
            if not mPlan then
                oPlayer.m_oBaseCtrl:UpdatePointPlan(iPlan, 0, iGrade)
            end
        end
    end
    oPlayer.m_oBaseCtrl:GS2CPointPlanInfoList()
end

function DeleteMail0621(oPlayer)
    local oMailBox = oPlayer:GetMailBox()
    for iMail, oMail in pairs(oMailBox.m_mMailIDs) do
        if oMail:GetData("title") == "6月21日例行版本更新维护结束" then
            oMailBox:DelMail(iMail)
        end            
    end
    global.oMailMgr:OnLogin(oPlayer)
end

function DeleteLeadTask(oPlayer)
    local mList = oPlayer.m_oTaskCtrl:TaskList()
    for iTaskId, oTask in pairs(mList) do
        local sDir = oTask:GetDirName()
        if sDir == "lead" then 
            local iLinkId = oTask:GetLinkId()
            local iConfigLinkId = oTask:GetConfigLinkId()
            if not iLinkId or iLinkId ~= iConfigLinkId then
                oTask:FullRemove()
            end
        end
    end
end

local mFuncList = {
    [1] = ReturnPartnerSilver,          --返还伙伴装备强化银币
    [2] = ResetGradeGiftMark,           --调整一本万利贰等级条件
    [3] = FixMailBugKaifudianli,        --调整修复冲级榜奖励
    [4] = ResetGradeGiftMark1,          --调整一本万利贰等级条件
    [5] = ReturnItem10181,              --返还轻音仙子之灵
    [6] = CalCharge,                    --计算玩家充值
    [7] = ReturnItem11187,              --返还坐骑突破瑶池仙露
    [8] = ReturnItem10163,              --返还羽翼进阶七彩神羽
    [9] = CheckPointPlan,               --调整加点方案 
    [10] = DeleteMail0621,              --delete mail
    [11]= DeleteLeadTask,              --删除没有串起来的引导任务
}

COnlineOffsetMgr = {}
COnlineOffsetMgr.__index = COnlineOffsetMgr
inherit(COnlineOffsetMgr,logic_base_cls())

function COnlineOffsetMgr:New()
    local o = super(COnlineOffsetMgr).New(self)
    return o
end

function COnlineOffsetMgr:GetMaxVersion()
    local iMaxVersion = 0
    for iVersion,_ in pairs(mFuncList) do
        if iMaxVersion < iVersion then
            iMaxVersion = iVersion
        end
    end
    return iMaxVersion
end

function COnlineOffsetMgr:OnLogin(oPlayer)
    local iCurVersion = oPlayer.m_oActiveCtrl:GetData("offset", 0)
    local iMaxVersion = self:GetMaxVersion()
    if iCurVersion >= iMaxVersion then
        return
    end
    oPlayer.m_oActiveCtrl:SetData("offset",iMaxVersion)
    for iVersion = iCurVersion+1,iMaxVersion do
        local sFunc = mFuncList[iVersion]
        if sFunc then
            safe_call(sFunc, oPlayer)
        end
    end
end
