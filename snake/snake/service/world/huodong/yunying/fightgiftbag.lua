local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"

local gamedefines = import(lualib_path("public.gamedefines"))
local huodongbase = import(service_path("huodong.huodongbase"))
local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))

function ScoreSort(a,b)
    return a<b
end

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "战力礼包"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mRewardInfo = {}
    o.m_mScorePid = {}
    return o
end

function CHuodong:IsSysOpen()
    local sServerKey = get_server_key()
    if sServerKey == "pro_gs10001" then
        return false
    end
    return true
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if not self:IsSysOpen() then
        return
    end
    local pid = oPlayer:GetPid()
    if not self:IsEnd(pid) then
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:Save()
    local mData = {}
    local mRewardInfo = {}
    for pid,mReward in pairs(self.m_mRewardInfo) do
        mRewardInfo[db_key(pid)]  = table_to_db_key(mReward)
    end
    mData.rewardinfo = mRewardInfo
    mData.scorepid =  table_to_db_key(self.m_mScorePid)
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    local mRewardInfo = {}
    for sPid,mReward in pairs(mData.rewardinfo or {}) do
        mRewardInfo[tonumber(sPid)]  = table_to_int_key(mReward)
    end
    self.m_mRewardInfo = mRewardInfo
    self.m_mScorePid =  table_to_int_key(mData.scorepid or {})
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "huodong fightgiftbag without data"
    end

    self:Dirty()
    for sPid,mReward in pairs(mFromData.rewardinfo or {}) do
        self.m_mRewardInfo[tonumber(sPid)]  = table_to_int_key(mReward)
    end

    local mScore = table_to_int_key(mFromData.scorepid or {})
    for iScore, lPid in pairs(mScore) do
        if not self.m_mScorePid[iScore] then
            self.m_mScorePid[iScore] = {}
        end
        list_combine(self.m_mScorePid[iScore], lPid)
    end
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:GetGameState(bNewDay)
end

function CHuodong:IsExtraOpenDay()
    local iOpenDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    local iServerOpenDay = global.oWorldMgr:GetOpenDays()
    if iOpenDay<iServerOpenDay then
        return false
    else
        return true
    end
end

function CHuodong:OnScoreChange(oPlayer,iCurScore)
    if not self:IsSysOpen() then
        return
    end
    local pid = oPlayer:GetPid()
    if self:IsEnd(pid) then
        return
    end
    local bRefresh = false
    local mConfigRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    local iRankLImit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["extra_limit"]
    local lScoreKey = table_key_list(mConfigRes)
    table.sort(lScoreKey,ScoreSort)
    for _,iScore in ipairs(lScoreKey) do
        if iCurScore<iScore then
            break
        end
        local mReward = self.m_mRewardInfo[pid]
        if not mReward then
            self.m_mRewardInfo[pid] = {}
            mReward = self.m_mRewardInfo[pid]
        end
        local mScoreReward = mReward[iScore]
        if not mScoreReward then
            mReward[iScore] = {}
            mScoreReward = mReward[iScore]
        end

        local iReward = mScoreReward.reward or 0
        if iReward==1 then
            goto continue
        end
        self:Dirty()
        bRefresh = true
        mScoreReward.reward = 1
        local lScorePid = self.m_mScorePid[iScore]
        if not lScorePid then
            lScorePid = {}
        end
        local iRank = 0
        if #lScorePid<iRankLImit and self:IsExtraOpenDay()  then
            table.insert(lScorePid,pid)
            iRank = #lScorePid
        end
        self.m_mScorePid[iScore] = lScorePid
        local mLogData = {}
        mLogData.pid = pid
        mLogData.score = iScore
        mLogData.rank = iRank
        record.log_db("huodong", "fightgiftbag_reward",mLogData)
        ::continue::
    end
    if bRefresh then
        self:GS2CGameReward(oPlayer)
    end
end

function CHuodong:GetReward(oPlayer,iScore)
    local pid = oPlayer:GetPid()
    if self:IsEnd(pid) then
        return
    end
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    local mScoreReward = mReward[iScore]
    if not mScoreReward then
        return
    end
    local iReward = mScoreReward.reward or 0
    if iReward ~= 1 then
        return
    end
    local iRewarded = mScoreReward.rewarded or 0
    if iRewarded == 1 then
        return
    end
    local mConfigRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    if not mConfigRes[iScore] then
        return
    end
    local rewardlist  = self:GetSlotReward(pid,mScoreReward,mConfigRes[iScore])
    if #rewardlist<=0 then
        return
    end

    local itemlist = {}
    for _,iItemRewardIdx in ipairs(rewardlist) do
        local iteminfo = self:InitRewardItem(oPlayer,iItemRewardIdx,{})
        list_combine(itemlist,iteminfo["items"])
    end
    if #itemlist<0 then
        return
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<#itemlist then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),global.oToolMgr:GetTextData(3015))
        return false
    end
    if not oPlayer:ValidGiveitemlist(itemlist,{cancel_tip = true}) then
        oNotifyMgr:Notify(pid,self:GetTextData(1004))
        return
    end
    local mLogData = {}
    mLogData.pid = pid
    mLogData.score = iScore
    mLogData.reward = extend.Table.serialize(rewardlist)
    record.log_db("huodong", "fightgiftbag_rewarded",mLogData)
    oPlayer:GiveItemobj(itemlist,self.m_sName,{})
    self:Dirty()
    mScoreReward.rewarded = 1
    self:GS2CGameReward(oPlayer)
end

function CHuodong:GetSlotReward(pid,mScoreReward,mRewardData)
    local rewardlist = {}
    for sSlot,mSlotReward in pairs(mRewardData) do
        local iScore = mRewardData.score
        if not (string.find(sSlot,"slot") or (sSlot == "extra" and self:HasExtraReward(pid,iScore) )) then
            goto continue
        end
        if #mSlotReward<=0 then
            goto continue
        end
        local iSlot = mScoreReward[sSlot] or 1
        if not mSlotReward[iSlot] then
            iSlot = 1
        end
        table.insert(rewardlist,mSlotReward[iSlot])
        ::continue::
    end
    return rewardlist
end

function CHuodong:HasExtraReward(pid,iScore)
    if not self.m_mScorePid[iScore] then
        return false
    end
    if extend.Array.find(self.m_mScorePid[iScore],pid) then
        return true 
    end
    return false
end

function CHuodong:SetChoice(oPlayer,iScore,sFlag,iIndex)
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return
    end
    if not sFlag then
        return
    end
    if not iIndex then
        return
    end
    local mScoreReward = mReward[iScore]
    if not mScoreReward then
        return
    end
    local iReward = mScoreReward.reward or 0
    if iReward ~= 1 then
        return
    end
    local iRewarded = mScoreReward.rewarded or 0
    if iRewarded == 1 then
        return
    end
    local mConfigRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    if not mConfigRes[iScore] then
        return
    end
    local mConfigResReward = mConfigRes[iScore]
    if not mConfigResReward[sFlag] then
        return
    end
    if not mConfigResReward[sFlag][iIndex] then
        return
    end
    self:Dirty()
    mScoreReward[sFlag] = iIndex
    self:GS2CGameReward(oPlayer)
end

function CHuodong:IsEnd(pid)
    local mReward = self.m_mRewardInfo[pid]
    if not mReward then
        return false
    end
    local mConfigRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    for iScore,mConfigResReward in pairs(mConfigRes) do
        local mScoreReward = mReward[iScore] 
        if not mScoreReward then
            return false
        end
        local iReward = mScoreReward.reward or 0
        if iReward ~= 1 then
            return false
        end
        local iRewarded =mScoreReward.rewarded or 0
        if iRewarded~=1  then
            return false
        end
    end
    return true
end

function CHuodong:GetEndTime()
    local iOpenDay = res["daobiao"]["huodong"][self.m_sName]["config"][1]["gameday"]
    local iServerOpenDay = global.oWorldMgr:GetOpenDays()
    local iEndTime = 0
    local iLeftDay = iOpenDay - iServerOpenDay
    if iLeftDay>0 then
        local iTime = get_time() + iLeftDay* 3600 * 24
        local date = os.date("*t",iTime)
        iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})
    end
    return iEndTime
end

function CHuodong:GetRankInfo(iScore,pid)
    local iRankLImit = res["daobiao"]["huodong"][self.m_sName]["config"][1]["extra_limit"]
    if not self.m_mScorePid[iScore] then
        return iRankLImit,0
    end
    local plist = self.m_mScorePid[iScore]
    local iPos = extend.Array.find(plist,pid)
    if not iPos then
        return math.max(0,iRankLImit-#plist),0
    end
    return iPos,1
end

function CHuodong:GS2CGameReward(oPlayer)
    local pid = oPlayer:GetPid()
    local mNet = {}
    local mReward = self.m_mRewardInfo[pid] or {}
    local rewardlist = {}
    local mConfigRes = res["daobiao"]["huodong"][self.m_sName]["reward"]
    for iScore,mInfo in pairs(mConfigRes) do
        if mReward[iScore] then
            local mScoreReward = mReward[iScore]
            local mRewardNet = {}
            mRewardNet.score = iScore
            mRewardNet.reward = mScoreReward.reward or 0
            mRewardNet.rewarded = mScoreReward.rewarded or 0
            local mSlotNet = {}
            for k,v in pairs(mScoreReward) do
                local iStart,iEnd = string.find(k,"slot") 
                if iStart and iEnd then
                    local iSlot = tonumber(string.sub(k,iEnd+1,#k))
                    if iSlot then
                        table.insert(mSlotNet,{slot = iSlot,index = v })
                    end
                end
                if k == "extra" then
                    table.insert(mSlotNet,{slot = 0,index = v })
                end
            end
            mRewardNet.slotlist = mSlotNet
            local rank,inrank = self:GetRankInfo(iScore,pid)
            mRewardNet.rank = rank
            mRewardNet.inrank = inrank
            table.insert(rewardlist,mRewardNet)
        else
            local mRewardNet = {}
            mRewardNet.score = iScore
            local rank,inrank = self:GetRankInfo(iScore,pid)
            mRewardNet.rank = rank
            mRewardNet.inrank = inrank
            table.insert(rewardlist,mRewardNet)
        end
    end
    mNet.rewardlist = rewardlist
    mNet.endtime = self:GetEndTime()
    oPlayer:Send("GS2CFightGiftbagReward",mNet)
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local mCommand={
        "100 指令查看",
        "101 清空自己数据\nhuodongop fightgiftbag 101",
        "102 清空所有数据\nhuodongop fightgiftbag 102",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag  == 101 then
        self.m_mRewardInfo[pid] = nil
        for iScore,plist in pairs(self.m_mScorePid) do
            extend.Array.remove(plist,pid)
        end
        self:GS2CGameReward(oPlayer)
        oNotifyMgr:Notify(pid,"清空完毕")
    elseif iFlag == 102 then
        self:Dirty()
        self.m_mRewardInfo = {}
        self.m_mScorePid = {}
        self:GS2CGameReward(oPlayer)
        oNotifyMgr:Notify(pid,"清空完毕")
    elseif iFlag == 201 then --huodongop fightgiftbag 201 {score=5000}
        self:OnScoreChange(oPlayer,mArgs.score)
    elseif iFlag == 202 then -- huodongop fightgiftbag 202 {score=5000}
        self:GetReward(oPlayer,mArgs.score)
    elseif iFlag == 203 then -- huodongop fightgiftbag 203 {score=5000,flag="slot4",index = 2}
        self:SetChoice(oPlayer,mArgs.score,mArgs.flag,mArgs.index)
    elseif iFlag == 204 then
        print(self.m_mRewardInfo)
        print(self.m_mScorePid)
    end
end

