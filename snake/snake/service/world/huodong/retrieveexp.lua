local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analylog = import(lualib_path("public.analylog"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "经验找回"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o:Init()
    return o
end

function CHuodong:Init()
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:CheckRetrieve(oPlayer)
    end
    self:GS2CRetrieveExp(oPlayer)
end

function CHuodong:CheckRetrieve(oPlayer)
    local iCurDayNo = get_morningdayno()

    -- 当天初始化一次，只要维护第一天的是处理即可
    self:InitCurDayRetrieve(oPlayer, iCurDayNo)
    
    -- TODO 第一次更新的时候需要，后面可以直接去掉
    local iBeginDayNo = get_morningdayno(1528248466)
    local iCreateDayNo = get_morningdayno(oPlayer:GetCreateTime())
    iBeginDayNo = math.max(iBeginDayNo, iCreateDayNo)
    if iCurDayNo <= iBeginDayNo then
        return
    end
    local lDayNo = table_key_list(oPlayer.m_oScheduleCtrl:GetAllRetrieveObj())
    for _,iDayNo in pairs(lDayNo) do
        if iCurDayNo - iDayNo > gamedefines.RETRIEVE_EXP_DAY then
            oPlayer.m_oScheduleCtrl:RemoveRetrieveObj(iDayNo)
        end
    end

    for i = 1, gamedefines.RETRIEVE_EXP_DAY do
        local iDayNo = iCurDayNo - i
        if iDayNo < iBeginDayNo then break end

        local oRetrieve = oPlayer.m_oScheduleCtrl:GetRetrieveObj(iDayNo)
        if not oRetrieve or not oRetrieve:isCalculate() then
            self:CalRetrievePerDay(oPlayer, iDayNo)
        end    
    end
end

function CHuodong:InitCurDayRetrieve(oPlayer, iCurDayNo)
    local oRetrieve = oPlayer.m_oScheduleCtrl:GetRetrieveObj(iCurDayNo)
    if oRetrieve then return end

    oRetrieve = oPlayer.m_oScheduleCtrl:AddRetrieveObj(iCurDayNo)
    for iSchedule, mData in pairs(self:GetAllRetrieveData()) do
        if iSchedule == 1004 then
            local iCnt = oPlayer.m_oTodayMorning:Query("ghost_base", 0)
            oRetrieve:DoSchedule(iSchedule, iCnt)            
        else
            local oSchedule = oPlayer.m_oScheduleCtrl:GetScheduleById(iSchedule)
            if oSchedule then
                oRetrieve:DoSchedule(iSchedule, oSchedule:GetDoneTimes())
            end
        end
    end 
end

function CHuodong:OnPlayerNewHour5(oPlayer, mNow)
    local iNowTime = mNow and mNow.time or get_time()
    local iDayNo = get_morningdayno(iNowTime) - 1
    
    self:CalRetrievePerDay(oPlayer, iDayNo)
    self:GS2CRetrieveExp(oPlayer, iNowTime)
end

function CHuodong:CalRetrievePerDay(oPlayer, iDayNo)
    local oRetrieve = oPlayer.m_oScheduleCtrl:GetRetrieveObj(iDayNo)
    if not oRetrieve then 
        oRetrieve = oPlayer.m_oScheduleCtrl:AddRetrieveObj(iDayNo)
    end

    for iSchedule, mData in pairs(self:GetAllRetrieveData()) do
        local sSys = mData["sys"]
        if #sSys <= 0 or (#sSys > 0 and global.oToolMgr:IsSysOpen(sSys, oPlayer, true)) then
            local iHasCnt = oRetrieve:GetScheduleTime(iSchedule)
            local iMaxCnt = mData["max_cnt"]
            if iHasCnt < iMaxCnt then
                oRetrieve:SetRetrieveCnt(iSchedule, iMaxCnt - iHasCnt)
            end
        end
    end 
    oRetrieve:SetCalculate()
end

function CHuodong:GS2CRetrieveExp(oPlayer, iNowTime)
    local iCurDayNo = get_morningdayno(iNowTime)
    local mRetrieve = oPlayer.m_oScheduleCtrl:GetCanRetrieveObj(iCurDayNo)

    local mSchedule = {}
    for _, oRetrieve in pairs(mRetrieve) do
        for iSchedule, iCnt in pairs(oRetrieve:GetAllRetrieve()) do
            mSchedule[iSchedule] = iCnt + (mSchedule[iSchedule] or 0)
        end
    end

    local lRetrieve = {}
    for iSchedule, iCnt in pairs(mSchedule) do
        table.insert(lRetrieve, {scheduleid=iSchedule, count=iCnt})
    end
    oPlayer:Send("GS2CRetrieveExp", {retrieves=lRetrieve})
end

function CHuodong:TryRetrieveExp(oPlayer, lSchedule, iType, iReqTime)
    if not global.oToolMgr:IsSysOpen("RETRIEVE_EXP", oPlayer) then
        return
    end

    if #lSchedule <= 0 then return end

    local iPid = oPlayer:GetPid()
    local iReqDayNo = get_morningdayno(iReqTime)
    local iCurDayNo = get_morningdayno()
    if iReqDayNo ~= iCurDayNo then
        self:GS2CRetrieveExp(oPlayer)
        return
    end 
    local mRetrieve = oPlayer.m_oScheduleCtrl:GetCanRetrieveObj(iCurDayNo)
    if not next(mRetrieve) then return end

    local mSchedule = {}
    for _, iSchedule in pairs(lSchedule) do
        for _, oRetrieve in pairs(mRetrieve) do
            local iCnt = oRetrieve:GetRetrieveCnt(iSchedule)
            if iCnt > 0 then
                mSchedule[iSchedule] = iCnt + (mSchedule[iSchedule] or 0)    
            end
        end
    end
    if not next(mSchedule) then
        oPlayer:NotifyMessage(self:GetText(1001))
        return
    end

    local iTotalExp = 0
    local mEnv = {grade=oPlayer:GetGrade()}
    if iType == 1 then
        local iTotalGold = 0
        for iSchedule, iCnt in pairs(mSchedule) do
            local mConfig = self:GetRetrieveDataById(iSchedule)
            iTotalGold = iTotalGold + mConfig["gold"] * iCnt
            iTotalExp = iTotalExp + formula_string(mConfig["exp"], mEnv) * iCnt
        end
        local iRatio = self:GetGlobalConfig("gold_ratio")
        iTotalExp = math.floor(iTotalExp * iRatio / 100)
        if not oPlayer:ValidGold(iTotalGold) then return end

        oPlayer:ResumeGold(iTotalGold, self.m_sTempName)
    elseif iType == 2 then
        local iGoldCoin = 0
        for iSchedule, iCnt in pairs(mSchedule) do
            local mConfig = self:GetRetrieveDataById(iSchedule)
            iGoldCoin = iGoldCoin + mConfig["goldcoin"] * iCnt
            iTotalExp = iTotalExp + formula_string(mConfig["exp"], mEnv) * iCnt
        end
        local iRatio = self:GetGlobalConfig("goldcoin_ratio")
        iTotalExp = math.floor(iTotalExp * iRatio / 100)
        if not oPlayer:ValidGoldCoin(iGoldCoin) then return end

        oPlayer:ResumeGoldCoin(iGoldCoin, self.m_sTempName)
    else
        for iSchedule, iCnt in pairs(mSchedule) do
            local mConfig = self:GetRetrieveDataById(iSchedule)
            iTotalExp = iTotalExp + formula_string(mConfig["exp"], mEnv) * iCnt
        end
        local iRatio = self:GetGlobalConfig("free_ratio")
        iTotalExp = math.floor(iTotalExp * iRatio / 100)
    end

    for _, oRetrieve in pairs(mRetrieve) do
        for iSchedule,_ in pairs(mSchedule) do
            oRetrieve:SetRetrieveCnt(iSchedule, nil)
        end
    end
    oPlayer:RewardExp(iTotalExp, self.m_sTempName, {bCancelAddRatio=true, bEffect=true})
    self:GS2CRetrieveExp(oPlayer)

    record.log_db("huodong", "retrieveexp", {
        pid = oPlayer:GetPid(), 
        type = iType,
        info = mSchedule,
        totalexp = iTotalExp,
    })
end

function CHuodong:GetText(iText, mReplace)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetSystemText({"huodong", self.m_sName}, iText, mReplace)
end

function CHuodong:GetGlobalConfig(sKey)
    return res["daobiao"]["huodong"][self.m_sName]["config"][1][sKey]
end

function CHuodong:GetAllRetrieveData()
    return res["daobiao"]["huodong"][self.m_sName]["retrieve"]
end

function CHuodong:GetRetrieveDataById(iSchedule)
    return self:GetAllRetrieveData()[iSchedule]
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local iPid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)

    local mCommand={
        "100 指令查看",
        "101 清掉全部数据\nhuodongop retrieveexp 101",
        "102 清掉当天数据\nhuodongop retrieveexp 102 ",
        "103 查看当天日程次数\nhuodongop retrieveexp 103 {1004}",
    }
    --sethdcontrol everydaycharge default 0 60
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer, mCommand[idx])
        end
        oPlayer:NotifyMessage("请看消息频道咨询指令")
    elseif iFlag  == 101 then
        local lDayNo = table_key_list(oPlayer.m_oScheduleCtrl:GetAllRetrieveObj())
        for _,iDayNo in pairs(lDayNo) do
            oPlayer.m_oScheduleCtrl:RemoveRetrieveObj(iDayNo)
        end
        oPlayer:NotifyMessage("执行成功")
    elseif iFlag == 102 then
        local iCurDayNo = get_morningdayno()
        oPlayer.m_oScheduleCtrl:RemoveRetrieveObj(iCurDayNo)
        oPlayer:NotifyMessage("执行成功")
    elseif iFlag == 103 then
        local iCurDayNo = get_morningdayno()
        local oRetrieve = oPlayer.m_oScheduleCtrl:GetRetrieveObj(iCurDayNo)
        local iCnt = 0
        if oRetrieve then
            iCnt = oRetrieve:GetScheduleTime(mArgs[1])
        end
        oPlayer:NotifyMessage(string.format("%s 完成次数 %s", mArgs[1], iCnt))
    elseif iFlag == 201 then
        local lSchedule = {1040}
        self:TryRetrieveExp(oPlayer, lSchedule, 0)
    end
end

