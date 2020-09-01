--import module
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local analy = import(lualib_path("public.dataanaly"))

local RAND_ITEM_COUNT = 6   --骰子个数
local MAX_CRAP_NUM = 6         --骰子最大数值

local SHOOT_MAX_CNT = 10          --每天投骰子最大限制
local SHOOT_DEFAULT_CNT=5       --每天投骰子默认次数
local SHOOT_GLODCOIN = 10 --每天元宝兑换次数
local GOLDNUMBER = 6 -- 目标数字 6666666

function NewHuodong( sHDName )
    return CHuodong:New(sHDName)
end

function _CheckOnlineTime(pid,iNextStartTime)
    local oHD = global.oHuodongMgr:GetHuodong("shootcraps")
    if oHD then
        oHD:CheckOnlineTime(pid,false,iNextStartTime)
    end
end

CHuodong = {}
CHuodong.__index  = CHuodong
CHuodong.m_sTempName = "投骰子"
inherit(CHuodong,huodongbase.CHuodong)

function CHuodong:New( sHDName )
    local o = super(CHuodong).New(self,sHDName)
    o.m_mResult = {}
    o.m_iScheduleID=1017
    return o
end

function CHuodong:Init()
    self:TryStartRewardMonitor()
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if self.m_mResult[oPlayer:GetPid()]then
        self:RunOver(oPlayer)
    end
end

function CHuodong:OnLogout(oPlayer)
    if self.m_mResult[oPlayer:GetPid()]then
        self:RunOver(oPlayer)
    end
end

function CHuodong:GetBasicItem()
     return res["daobiao"]["huodong"]["shootcraps"]["basicreward"][1]
end

function CHuodong:OpenUI( oPlayer )
    local iTotal=self:MaxTime(oPlayer)
    local sGoleNumFlag = string.format("%s_golenum_cnt",self.m_sName)
    local iGoleNum = oPlayer:Query(sGoleNumFlag,0)
    local mNet = {}
    mNet.count = oPlayer.m_oTodayMorning:Query("shootcraps_num",0)
    mNet.maxcount = iTotal
    mNet.goldcoincnt = self:GetGoldCoinCnt(oPlayer)
    mNet.sixcnt = iGoleNum
    oPlayer:Send("GS2CShootCrapOpen",mNet)
end

function CHuodong:ValidRun( oPlayer ,bGoldCoin)
    local oNotifyMgr = global.oNotifyMgr
    local iTotal=self:MaxTime(oPlayer)
    if oPlayer.m_oTodayMorning:Query("shootcraps_num",0) >= iTotal and not bGoldCoin then
        oNotifyMgr:Notify(oPlayer:GetPid()," 今日次数已经用完，明天再来吧")
        return false
    end
    return true
end

function CHuodong:MaxTime(oPlayer)
    local iMaxTime = SHOOT_DEFAULT_CNT+oPlayer.m_oTodayMorning:Query("shootcraps_extra",0) 
    return iMaxTime
end

function CHuodong:RunStart(oPlayer,bGoldCoin)
    local pid=oPlayer:GetPid()
    if not self:ValidRun(oPlayer,bGoldCoin) then return end
    if self.m_mResult[pid] then
        self:RunOver(oPlayer)
    end
    if not bGoldCoin then
        oPlayer.m_oTodayMorning:Add("shootcraps_num",1)
    end
    self:AddSchedule(oPlayer)
    oPlayer.m_oScheduleCtrl:HandleRetrieve(self.m_iScheduleId, 1)
    local mRes=res["daobiao"]["huodong"]["shootcraps"]["flowertype"]
    local mRadio={}
    local iFid=0
    for k,v in ipairs(mRes) do
        mRadio[v.flower]=v.weight
    end
    if oPlayer.m_HDSC_flowertype then
        mRadio[0]=nil
        oPlayer.m_HDSC_flowertype=nil
    end
    local iFlowerValue=extend.Random.choosekey(mRadio)
    if iFlowerValue ~= 0 then
        local lResult = {}
        for i=1 , GOLDNUMBER do
            if iFlowerValue>0 then
                table.insert(lResult,iFlowerValue%10)
                iFlowerValue = math.floor(iFlowerValue/10)
            else
                table.insert(lResult,1)
            end
        end
        table.sort(lResult,function(a,b)return a<b end)
        self.m_mResult[pid]=lResult
    else
        local mRadioRes = res["daobiao"]["huodong"]["shootcraps"]["sixratio"]
        mRadio = {}
        for _,mInfo in pairs(mRadioRes) do
            mRadio[mInfo.num]=mInfo.ratio
        end
        local iSixNum=extend.Random.choosekey(mRadio)
        iSixNum = math.max(iSixNum,0)
        iSixNum = math.min(iSixNum,GOLDNUMBER)
        local lResult = {}
        for i=1,iSixNum do
            table.insert(lResult,GOLDNUMBER)
        end
        for i=1,GOLDNUMBER-iSixNum do
            table.insert(lResult,math.random(1,GOLDNUMBER-1))
        end
        self.m_mResult[pid]=extend.Random.random_size(lResult,#lResult)

    end
    iFid= self:IsFlowerShape(pid) 
    if oPlayer.m_mSCSIX  then
        self.m_mResult[pid] = {6,6,6,6,6,6}
        oPlayer.m_mSCSIX = nil
    end
    local sGoleNumFlag = string.format("%s_golenum_cnt",self.m_sName)
    local iGoleNum = oPlayer:Query(sGoleNumFlag,0)
    oPlayer:Send("GS2CShootCrapEnd",{point_lst=self.m_mResult[pid],flowerid=iFid,sixcnt = iGoleNum})
end

function CHuodong:RunOver( oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not self.m_mResult[pid] then
        return
    end
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(pid, 1, 1) then
            return
        end
    end
    local iRewardAmount = 1 --经验和银币奖励数量
    local iFid = 0
    local iRadio =0
    local sFlowerName=""
    local mItem={}

    local mRecordReward = oPlayer:GetTemp("reward_content")
    if not mRecordReward then
        oPlayer:RecordAnalyContent()
        mRecordReward = oPlayer:GetTemp("reward_content")
    end
    
    iFid ,iRadio ,sFlowerName = self:IsFlowerShape(pid) 
    local mResult=extend.Table.deep_clone(self.m_mResult[pid])
    local sGoleNumFlag = string.format("%s_golenum_cnt",self.m_sName)
    local iSixCnt = 0
    for _,iNumber in ipairs(mResult) do
        if iNumber == GOLDNUMBER then
            iSixCnt = iSixCnt +1
        end
    end
    -- for _,iNumber in ipairs(mResult) do
    --     if iNumber == GOLDNUMBER then
    --         local iGoleNum = oPlayer:Query(sGoleNumFlag,0)
    --         oPlayer:Set(sGoleNumFlag,iGoleNum+1)
    --         iGoleNum = oPlayer:Query(sGoleNumFlag,0)
    --         if iGoleNum>=6 then
    --             oPlayer:Set(sGoleNumFlag, nil)
    --             self:Reward(pid,1001,{sixreward = true,cancel_tip = true,cancel_chat = true})
    --             break
    --         end
    --     end
    -- end
    local iGoleNum = oPlayer:Query(sGoleNumFlag, 0)
    oPlayer:Set(sGoleNumFlag, iGoleNum + iSixCnt)
    iGoleNum = oPlayer:Query(sGoleNumFlag, 0)
    if iGoleNum >= 6 then
        oPlayer:Set(sGoleNumFlag, iGoleNum-6)
        self:Reward(pid,1001,{sixreward = true,cancel_tip = true,cancel_chat = true})            
    end

    if iSixCnt == 6 then
        local mChuanwen = res["daobiao"]["chuanwen"][1065]
        local sContent = global.oToolMgr:FormatColorString(mChuanwen.content,{role = oPlayer:GetName()})
        global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
    end
    self.m_mResult[pid]=nil


    if iFid>0 and iRadio>0 then
        iRewardAmount = iRewardAmount *iRadio
    end
    
    local m_mBasicItem = self:GetBasicItem()
    if m_mBasicItem.itemsid > 0 then
        local oItem = global.oItemLoader:Create(m_mBasicItem.itemsid)
        oPlayer:RewardItem(oItem, "骰子基础奖励")
    end
    local sFormula = m_mBasicItem.silver
    local iValue = formula_string(sFormula, {lv = oPlayer:GetGrade()})
    iValue = math.floor(iValue)
    local iSilver = iValue*iRewardAmount

    local sFormula = m_mBasicItem.exp
    iValue = formula_string(sFormula, {lv = oPlayer:GetGrade()})
    iValue = math.floor(iValue)
    local iExp = iValue*iRewardAmount
    oPlayer:Send("GS2CShootCrapReward",{exp = iExp,silver = iSilver})
    oPlayer:RewardSilver(iSilver,"骰子奖励")
    oPlayer:RewardExp(iExp,"骰子奖励")
    mRecordReward[1005] = iExp
    mRecordReward[1002] = iSilver
    if iRewardAmount>1 then
        local oChatMgr=global.oChatMgr
        local mChuanwen = res["daobiao"]["chuanwen"][1031]
        local sMsg=string.format(mChuanwen.content,oPlayer:GetName(),sFlowerName,iRewardAmount)
        oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, mChuanwen.horse_race)
    end

    local iTotal=self:MaxTime(oPlayer)
    local sGoleNumFlag = string.format("%s_golenum_cnt",self.m_sName)
    local iGoleNum = oPlayer:Query(sGoleNumFlag,0)
    local sixlitemlist = oPlayer.m_iShootCrapsSixRewardItem or {}
    local mNet = {}
    mNet.maxcount = iTotal
    mNet.count = oPlayer.m_oTodayMorning:Query("shootcraps_num",0)
    mNet.goldcoincnt = self:GetGoldCoinCnt(oPlayer)
    mNet.sixcnt = iGoleNum
    mNet.sixlitemlist = sixlitemlist
    oPlayer:Send("GS2CShootCrapUpdate",mNet)
    oPlayer.m_iShootCrapsSixRewardItem = nil

    safe_call(self.LogAnalyInfo, self, oPlayer, iRewardAmount > 1)
end

function CHuodong:RewardItems(oPlayer, mAllItems, mArgs)
    if mArgs.sixreward then
        local itemlist = {}
        for itemidx, mItems in pairs(mAllItems) do
            local lItems = mItems["items"]
            for _, oItem in ipairs(lItems) do
                table.insert(itemlist,oItem:SID())
            end
        end
        oPlayer.m_iShootCrapsSixRewardItem = itemlist
        mArgs.refresh = 1
        mArgs.cancel_chat = true
        mArgs.cancel_tip = true
    end
    super(CHuodong).RewardItems(self,oPlayer, mAllItems, mArgs)
end

function CHuodong:IsFlowerShape( pid )
    local bExtraReward = true
    local lResult = extend.Table.deep_clone(self.m_mResult[pid])
    table.sort(lResult,function(a,b)return a>b end)
    local iValue=0
    local mRes = res["daobiao"]["huodong"]["shootcraps"]["flowertype"]
    for k,v in ipairs(lResult) do
        iValue = iValue +v*(10^(k-1))
    end
    iValue =  math.floor(iValue)
    for i,mInfo in ipairs(mRes) do
        if mInfo.flower == iValue then
            return mInfo.id,mInfo.radio,mInfo.name
        end
    end
    return 0,0,""
end

function CHuodong:LogAnalyInfo(oPlayer, isLucky)
    if not oPlayer then return end

    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["turn_times"] = oPlayer.m_oTodayMorning:Query("shootcraps_num", 0)
    mAnalyLog["is_lucky"] = isLucky
    local mReward = oPlayer:GetTemp("reward_content", {})
    mAnalyLog["reward_detail"] = analy.table_concat(mReward)
    analy.log_data("dice", mAnalyLog)
end

function CHuodong:ExchangeCnt(oPlayer)
    local sFlag = string.format("%s_exchange",self.m_sName)
    local iExchangeCnt = oPlayer.m_oTodayMorning:Query(sFlag,0)
    if iExchangeCnt >=SHOOT_GLODCOIN then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        return 
    end
    local mConfig = res["daobiao"]["huodong"][self.m_sName]["config"][1]
    local sFormula = mConfig.exchange_goldcoin
    local iExchangeGoldCoin = formula_string(sFormula,{cnt = iExchangeCnt})
    if not oPlayer:ValidGoldCoin(iExchangeGoldCoin,self.m_sName) then
        return 
    end
    assert(iExchangeGoldCoin>0)
    oPlayer.m_oTodayMorning:Add(sFlag,1)
    oPlayer:ResumeGoldCoin(iExchangeGoldCoin,self.m_sName)
    self:RunStart(oPlayer,true)
end

function CHuodong:GetGoldCoinCnt(oPlayer)
    local sFlag = string.format("%s_exchange",self.m_sName)
    local iExchangeCnt = oPlayer.m_oTodayMorning:Query(sFlag,0)
    return iExchangeCnt
end

function CHuodong:GetGoldCoinMaxCnt()
    return SHOOT_GLODCOIN
end

---------测试指令-----------
function CHuodong:TestOp(iFlag,arg)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local oWorldMgr = global.oWorldMgr
    local pid = arg[#arg]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
     local mCommand={
      "100  指令查看",
      "101  清除次数限制\nhuodongop shootcraps 101",
      "102  设置下次摇奖触发花型,类型为1或2\nhuodongop shootcraps 102",
      "103  清除6进度\nhuodongop shootcraps 103",
      "104  摇出6个6\nhuodongop shootcraps 104",
      "105  查看已经记录的时间\nhuodongop shootcraps 105",
      "305  增加次数\nhuodongop shootcraps 305 {point = 20}",
    }
    if iFlag == 100 then --huodongop shootcraps 100
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end 
    elseif iFlag == 101 then
        oPlayer.m_oTodayMorning:Delete("shootcraps_num")
        oPlayer.m_oTodayMorning:Delete("shootcraps_extra")
        oPlayer.m_oTodayMorning:Delete("shootcraps_exchange")
        local oSch = oPlayer.m_oScheduleCtrl.m_mSchedules[self.m_iScheduleID]
        if oSch then
            oSch:SetData("donetimes",0)
            oPlayer.m_oScheduleCtrl:Refresh()
        end
    elseif iFlag == 102 then
        oPlayer.m_HDSC_flowertype = 1
    elseif iFlag == 103 then
        local sGoleNumFlag = string.format("%s_golenum_cnt",self.m_sName)
        oPlayer:Set(sGoleNumFlag,nil)
    elseif iFlag == 104 then
        oPlayer.m_mSCSIX = true
    elseif iFlag == 105 then
        local sFlag = string.format("%s_online_%s",self.m_sName,pid)
        local iTime = oPlayer.m_oTodayMorning:Query(sFlag,0)
        oChatMgr:HandleMsgChat(oPlayer,string.format("时间%s",iTime))
    elseif iFlag == 304 then
        self:RunOver(oPlayer)
    elseif iFlag ==305 then
        self:ExchangeCnt(oPlayer)
    elseif iFlag == 306 then 
        self:RunStart(oPlayer)
    end
    oNotifyMgr:Notify(oPlayer:GetPid()," 执行完毕")
end


