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

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "开服典礼"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_mTouXian = {}
    o.m_mOrgCnt = {}
    o.m_mOrgLevel = {}
    o.m_mRewardInfo = {}
    o:Init()
    return o
end

function CHuodong:Init()
    self:IsKaiFuAllRankEnd()
end

function CHuodong:Save()
    local mData = {}
    local mTXData = {}
    for iLevel,mData1 in pairs(self.m_mTouXian) do
        local sLevel = db_key(iLevel)
        mTXData[sLevel] = {}
        for pid,mData2 in pairs(mData1) do
            local sPid = db_key(pid)
            mTXData[sLevel][sPid] = mData2
        end
    end
    mData.touxian = mTXData
    mData.orgcnt = table_to_db_key(self.m_mOrgCnt)
    mData.orglevel = table_to_db_key(self.m_mOrgLevel)
    mData.rewardinfo = self.m_mRewardInfo
    return mData
end

function CHuodong:Load(mData)
    mData = mData or {}
    local mTXData = mData.touxian or {}
    for sLevel , mData1 in pairs(mTXData) do
        local  iLevel = tonumber(sLevel)
        mTXData[iLevel] = {}
        for sPid,mData2 in pairs(mData1) do
            local pid = tonumber(sPid)
            mTXData[iLevel][pid] = mData2
        end
    end
    self.m_mTouXian = mTXData
    self.m_mOrgCnt = table_to_int_key(mData.orgcnt or {})
    self.m_mOrgLevel = table_to_int_key(mData.orglevel or {})
    self.m_mRewardInfo = mData.rewardinfo or {}
    self:InitRewardInfo()
end

function CHuodong:InitRewardInfo()
    local lRankName = {"orgcnt","orglevel","playerscore","playergrade"}
    for _,sRewardFlag  in ipairs(lRankName) do
        if not self.m_mRewardInfo[sRewardFlag] then
            self:Dirty()
            self.m_mRewardInfo[sRewardFlag] = {}
        end
    end
end

function CHuodong:MergeFrom(mFromData)
    return true
end

function CHuodong:NeedSave()
    return true
end

function CHuodong:GetFortune(iMoneyType, mArgs)
    return false
end

function CHuodong:ValidPush()
    if not global.oToolMgr:IsSysOpen("KAIFUDIANLI", nil,true) then 
        return false
    end
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"]
    local iDay = 0
    for sKey , mInfo in pairs(mRes) do
        local iOpenDay = mInfo["openday"]
        if iOpenDay>iDay then
            iDay = iOpenDay
        end
    end
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    if iDay>=iOpenDay then
        return true
    elseif iDay == iOpenDay-1 then
        local date = os.date("*t",get_time())
        if date.hour == 0 then
            return true
        else
            return false
        end
    else
        return false
    end
end

function CHuodong:NewHour(mNow)
    local iHour = mNow.date.hour
    if iHour == 0 then
        --self:CheckQueryRank()
    end
    for pid ,oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        self:GS2CKaiFuRankReward(oPlayer)
    end
end

function CHuodong:NewDay(mNow)
    self:IsKaiFuAllRankEnd()
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    if not bReEnter then
        self:CheckOrgRewardFlag(oPlayer)
        self:CheckOrgRankReward(oPlayer)
    end
    self:GS2CKaiFuRankReward(oPlayer)
    self:AddUpgradeEvent(oPlayer)
end

function CHuodong:OnLogout(oPlayer)
    if self:ValidPush() then
        self:PushSingleRank(oPlayer)
    end
end

function CHuodong:CheckQueryRank(mNow)
    local iHour = mNow.date.hour
    if iHour ~= 0 then return end

    local iSerOpenDay = global.oWorldMgr:GetOpenDays()
    local mRes =res["daobiao"]["huodong"][self.m_sName]["config"]
    local lQueryName = {}
    for sRankName , mInfo in pairs(mRes) do
        if mInfo.openday + 1  == iSerOpenDay then
            if sRankName ~= "kaifu_touxian" then
                table.insert(lQueryName,sRankName)
            else
                self:RewardTXRank()
            end
        end
    end
    if #lQueryName > 0 then
        for _, sRankName in pairs(lQueryName) do
            self:RemoteQueryRankReward(sRankName)
        end
    end
end

function CHuodong:RemoteQueryRankReward(sRankName)
    local mData = {}
    mData.rankname = sRankName
    mData.frozen = true
    interactive.Request(".rank", "rank", "GetKaiFuData", mData,
    function(mRecord, mData)
        OnRemoteQueryRankReward(mData)
    end)
end

function CHuodong:RewardRank(mData)
    local oWorldMgr = global.oWorldMgr
    local sRankName = mData.rankname
    if not sRankName then
        return
    end
    local mRewardData = mData.rewarddata or {}
    self:EndReward(sRankName)
    if #mRewardData <=0 then
        return 
    end
    if extend.Array.find({"kaifu_grade","kaifu_score","kaifu_summon"},sRankName) then
        for iRank ,pid in ipairs(mRewardData) do
            local iReward = self:GetRankReward(sRankName,iRank)
            if not iReward then
                goto continue 
            end
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                self:Reward(pid,iReward)
            else
                global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iReward})
            end
            ::continue::
        end
    elseif sRankName == "kaifu_org" then
        local oOrgMgr = global.oOrgMgr
        local iCurTime = get_time()
        local iJoinLimit = res["daobiao"]["huodong"][self.m_sName]["config"]["kaifu_org"]["joinlimit"]
        for iRank ,orgid in ipairs(mRewardData) do
            local orgobj = oOrgMgr:GetNormalOrg(orgid)
            if not orgobj then
                goto continue 
            end 
            local iRewardTitle = self:GetRankRewardTitle(sRankName,iRank)
            if not iRewardTitle then
                goto continue 
            end
            local iLeaderReward = self:GetLeaderReward(sRankName,iRank)
            local iMemReward = self:GetMemReward(sRankName,iRank)
            local iRedPacket = self:GetRedpacket(sRankName,iRank)

            local mOrgMember = orgobj.m_oMemberMgr:GetMemberMap()

            for pid,oMem in pairs(mOrgMember) do
                local iJoinTime = oMem:GetJoinTime()
                if iCurTime - iJoinTime <iJoinLimit then
                    goto continue2
                end
                global.oTitleMgr:AddTitle(pid,iRewardTitle)
                if oMem:GetPosition() == orgdefines.ORG_POSITION.LEADER then
                    if iLeaderReward then
                       if oPlayer then
                            self:Reward(pid,iLeaderReward)
                        else
                            global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iLeaderReward})
                        end
                    end
                    if  iRedPacket then
                        global.oRedPacketMgr:AddRPBuff(pid,iRedPacket) 
                    end
                elseif oMem:GetPosition() == orgdefines.ORG_POSITION.DEPUTY then
                    if iLeaderReward then
                       if oPlayer then
                            self:Reward(pid,iLeaderReward)
                        else
                            global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iLeaderReward})
                        end
                    end
                else
                    if iMemReward then
                       if oPlayer then
                            self:Reward(pid,iMemReward)
                        else
                            global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iMemReward})
                        end
                    end
                end
                ::continue2::
            end
            ::continue::
        end
    end
end

function CHuodong:EndReward(sRankName)
    local lRankFlag = {
    ["kaifu_grade"]= {{"playergrade","kaifu_grade_"}},
    ["kaifu_score"]= {{"playerscore","kaifu_score_"}},
    ["kaifu_org"] = {{"orgcnt","kaifu_orgcnt_"},{"orglevel","kaifu_orglevel_"}},
    }
    if not lRankFlag[sRankName] then
        return
    end
    self:Dirty()
    for _,mData1 in pairs(lRankFlag[sRankName]) do
        local sConfig = mData1[1]
        local sPreFlag = mData1[2]
        local mRes = res["daobiao"]["huodong"][self.m_sName][sConfig]
        local mRewardInfo = self.m_mRewardInfo[sConfig]
        self.m_mRewardInfo[sConfig] = {}
        for pid,lRewardFlag in pairs(mRewardInfo) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            local rewardlist = {}
            local itemlist = {}
            for iKey,mInfo in pairs(mRes) do
                local sFlag = string.format("%s%s",sPreFlag,iKey)
                if extend.Array.find(lRewardFlag,sFlag) then
                    table.insert(rewardlist,mInfo.reward)
                    if oPlayer then
                        oPlayer.m_oThisTemp:Delete(sFlag)
                    end
                end
            end
            for _,iReward in ipairs(rewardlist) do
                local mRewardData = res["daobiao"]["reward"][self.m_sName]["reward"][iReward]
                for _,itemreward in pairs(mRewardData.item) do
                    local mItemRewardInfo = self:GetItemRewardData(itemreward)
                    if mItemRewardInfo then
                        local mItemInfo = self:ChooseRewardKey(oPlayer, mItemRewardInfo, itemreward, {})
                        if mItemInfo then
                            local iteminfo = self:InitRewardByItemUnitOffline(pid,itemreward,mItemInfo)
                            list_combine(itemlist,iteminfo["items"])
                        end
                    end
                end
            end
            if #itemlist>0 then
                local mMailReward = {}
                mMailReward["items"] = itemlist
                self:SendMail(pid,2046,mMailReward)
            end
        end
    end
end

function CHuodong:InitRewardByItemUnitOffline(pid, itemidx, mItemInfo)
    local mItems = {}
    local sShape = mItemInfo["sid"]
    local iBind = mItemInfo["bind"]
    if type(sShape) ~= "string" then
        print(debug.traceback(""))
        return
    end
    local iAmount = mItemInfo["amount"]
    local oItem = global.oItemLoader:ExtCreate(sShape, {})
    oItem:SetAmount(iAmount)
    if iBind ~= 0 then
        oItem:Bind(pid)
    end
    mItems["items"] = {oItem}
    return mItems
end

function CHuodong:GetRankReward(sRankName,iRank)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sRankName]
    local ranklist = mRes.rewardlist
    local iReward 
    for _,mReward in ipairs(ranklist) do
        if iRank<=mReward["rank"] then
            iReward =  mReward["reward"]
            break
        end
    end
    return iReward
end

function CHuodong:GetRankRewardTitle(sRankName,iRank)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sRankName]
    local ranklist = mRes.titlelist
    local iRewardTitle 
    for _,mReward in ipairs(ranklist) do
        if iRank<=mReward["rank"] then
            iRewardTitle =  mReward["title"]
            break
        end
    end
    return iRewardTitle
end

function CHuodong:GetLeaderReward(sRankName,iRank)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sRankName]
    local ranklist = mRes.leaderreward
    local iReward 
    for _,mReward in ipairs(ranklist) do
        if iRank<=mReward["rank"] then
            iReward =  mReward["reward"]
            break
        end
    end
    return iReward
end

function CHuodong:GetMemReward(sRankName,iRank)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sRankName]
    local ranklist = mRes.orgmember
    local iReward 
    for _,mReward in ipairs(ranklist) do
        if iRank<=mReward["rank"] then
            iReward =  mReward["reward"]
            break
        end
    end
    return iReward
end

function CHuodong:GetRedpacket(sRankName,iRank)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sRankName]
    local ranklist = mRes.redpacket
    local iReward 
    for _,mReward in ipairs(ranklist) do
        if iRank<=mReward["redpacket"] then
            iReward =  mReward["redpacket"]
        end
    end
    return iReward
end

function CHuodong:GetShowTX()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"]["kaifu_touxian"]
    return mRes.showtx
end

function CHuodong:RewardTXRank()
    local sRankName = "kaifu_touxian"
    local oWorldMgr = global.oWorldMgr
    local iShowTX = self:GetShowTX()
    for iLevel,mInfo in pairs(self.m_mTouXian) do
        if iLevel ~= iShowTX then
            goto continue
        end
        for pid,mSubInfo in pairs(mInfo) do
            local iRank = mSubInfo.rank
            local pid = mSubInfo.pid
            local iReward = self:GetRankReward(sRankName,iRank)
            if iReward then
                local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
                if oPlayer then
                    self:Reward(pid,iReward)
                else
                    global.oPubMgr:OnlineExecute(pid, "HuodongReward", {self.m_sName, iReward})
                end
            end
        end
        ::continue::
    end
end

function CHuodong:TryPushData2Rank(oPlayer)
    if oPlayer and oPlayer:GetGrade() >= 30 and self:ValidPush() then
        self:PushSingleRank(oPlayer)
    end
end

function CHuodong:PushSingleRank(oPlayer)
    local mNet = {}
    mNet.flag = 1
    mNet.data = self:PackPlayerRankData(oPlayer)
    interactive.Send(".rank", "rank", "PushKaiFuDianLi", mNet)
end

function CHuodong:PackPlayerRankData(oPlayer)
    local mData = {}
    mData.pid  = oPlayer:GetPid()
    mData.school  = oPlayer:GetSchool()
    mData.name = oPlayer:GetName()
    mData.touxian = oPlayer.m_oTouxianCtrl:GetTouxianID()
    mData.grade = oPlayer:GetGrade()
    mData.score = oPlayer:GetScore()
    mData.exp = oPlayer:GetExp()

    mData.kaifu_grade = self:PackPlayerGradeRank(oPlayer)
    mData.kaifu_summon = self:PackSumRankData(oPlayer)
    mData.kaifu_score = self:PackPlayerScoreRank(oPlayer)
    return mData
end

function CHuodong:PackSumRankData(oPlayer)
    local mData = nil
    local mRes = self:GetConfigData("kaifu_summon")
    if mRes["openday"] < global.oWorldMgr:GetOpenDays()-1 then
        return mData
    elseif mRes["openday"] == global.oWorldMgr:GetOpenDays()-1 then
        local date = os.date("*t",get_time())
        if date.hour ~= 0 then
             return mData
        end
    end
    local iJoinScore = res["daobiao"]["huodong"][self.m_sName]["config"]["kaifu_summon"]["joinscore"]
    local iScore = 0
    local oNeedSum = nil 
    for _, oSummon in pairs(oPlayer.m_oSummonCtrl.m_mSummons) do
        local iTargetScore = oSummon:GetScore() 
        if iTargetScore<iJoinScore then
            goto continue
        end
        if iTargetScore>iScore then
            iScore = iTargetScore
            oNeedSum = oSummon
        elseif iTargetScore== iScore and oNeedSum then
            if oSummon:CarryGrade()>oNeedSum:CarryGrade() then
                iScore = iTargetScore
                oNeedSum = oSummon
            end
        end
        ::continue::
    end
    if oNeedSum then
        mData = oNeedSum:GetRankData()
    end
    return mData
end

function CHuodong:PackPlayerScoreRank()
    local mRes = self:GetConfigData("kaifu_score")
    if mRes["openday"] < global.oWorldMgr:GetOpenDays()-1 then
        return false
    elseif mRes["openday"] == global.oWorldMgr:GetOpenDays()-1 then
        local date = os.date("*t",get_time())
        if date.hour ~= 0 then
             return false
        end
    end
    return true
end

function CHuodong:PackPlayerGradeRank()
    local mRes = self:GetConfigData("kaifu_grade")
    if mRes["openday"] < global.oWorldMgr:GetOpenDays()-1 then
        return false
    elseif mRes["openday"] == global.oWorldMgr:GetOpenDays()-1 then
        local date = os.date("*t",get_time())
        if date.hour ~= 0 then
             return false
        end
    end
    return true
end

function CHuodong:PushOrgData2Rank()
    if not self:ValidPush() then
        return
    end

    local mArgs = {
        flag = 2,
        data = {},
        kaifu_org = self:PackOrgRankData(),
    }
    interactive.Send(".rank", "rank", "PushKaiFuDianLi", mArgs)
end

function CHuodong:PackOrgRankData()
    local mRes = self:GetConfigData("kaifu_org")
    if mRes["openday"] < global.oWorldMgr:GetOpenDays()-1 then
        return false
    elseif mRes["openday"] == global.oWorldMgr:GetOpenDays()-1 then
        local date = os.date("*t",get_time())
        if date.hour ~= 0 then
             return false
        end
    end
    local mNet = {}
    local mOrg = global.oOrgMgr:GetNormalOrgs()
    for orgid,orgobj in pairs(mOrg) do
        local mData = {}
        mData.orgid = orgid
        mData.prestige = orgobj:GetPrestige()
        mData.orgname = orgobj:GetName()
        mData.name = orgobj:GetLeaderName()
        mData.orglv = orgobj:GetLevel()
        table.insert(mNet,mData)
    end
    return mNet
end

function CHuodong:GetConfigData(sType)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"][sType]
    return mRes
end


function CHuodong:TouxianUpGrade(oPlayer,iLevel)
    if not global.oToolMgr:IsSysOpen("KAIFUDIANLI", oPlayer,true) then 
        return false
    end
    local pid = oPlayer:GetPid()
    if iLevel ~= self:GetShowTX() then
        return false
    end
    if not self.m_mTouXian[iLevel] then
        self.m_mTouXian[iLevel] = {}
    end
    local mLevelTouxian = self.m_mTouXian[iLevel]
    local iCnt = table_count(mLevelTouxian)
    if iCnt >10 then
        return
    end
    self:Dirty()

    local mData = {}
    mData.pid  = oPlayer:GetPid()
    mData.name = oPlayer:GetName()
    mData.rank = iCnt + 1
    mLevelTouxian[pid] = mData
    self.m_mTouXian[iLevel] = mLevelTouxian
end

function CHuodong:OnLeaveOrg(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:GS2CKaiFuRankReward(oPlayer)
    end
end

function CHuodong:OnOrgLevel(orgobj)
    if not global.oToolMgr:IsSysOpen("KAIFUDIANLI", nil,true) then 
        return false
    end
    local sRankName = "kaifu_org"
    local mConfig = self:GetConfigData(sRankName)
    local mRes = res["daobiao"]["huodong"][self.m_sName]["orglevel"]
    local iLevel = orgobj:GetLevel()
    local orgid = orgobj:OrgID()
    if not mRes[iLevel] then
        return
    end

    local iOpenDay = mRes[iLevel]["openday"]
    local iOpenDay2 = mConfig["openday"]
    if iOpenDay<global.oWorldMgr:GetOpenDays() then
        return
    end
    -- if iOpenDay2 < iOpenDay then
    --     return 
    -- end
    if not self.m_mOrgLevel[iLevel] then
        self.m_mOrgLevel[iLevel] = {}
    end
    if extend.Array.find(self.m_mOrgLevel[iLevel],orgid) then
        return
    end
    self:Dirty()
    table.insert(self.m_mOrgLevel[iLevel],orgid)
    local mMember = orgobj:GetOnlineMembers()
    for pid,oPlayer in pairs(mMember) do 
        self:CheckOrgRankReward(oPlayer)
    end 
end

function CHuodong:OnOrgCnt(orgobj,pid)
    if not global.oToolMgr:IsSysOpen("KAIFUDIANLI", nil,true) then 
        return false
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:CheckOrgRewardFlag(oPlayer)
        self:GS2CKaiFuRankReward(oPlayer)
    end
    local mConfig = self:GetConfigData("kaifu_org")
    local mRes = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]
    local iCnt = orgobj:GetMemberCnt()
    local orgid = orgobj:OrgID()
    if not mRes[iCnt] then
        return
    end
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local iOpenDay1 = mRes[iCnt]["openday"]
    local iOpenDay2 = mConfig["openday"]
    if iOpenDay1< iOpenDay then
        return
    end
    -- if iOpenDay2 < iOpenDay then
    --     return 
    -- end
    if not self.m_mOrgCnt[iCnt] then
        self.m_mOrgCnt[iCnt] = {}
    end
    if extend.Array.find(self.m_mOrgCnt[iCnt],orgid) then
        return
    end
    self:Dirty()
    table.insert(self.m_mOrgCnt[iCnt],orgid)
    local mMember = orgobj:GetOnlineMembers()
    for pid,oPlayer in pairs(mMember) do 
        self:CheckOrgRankReward(oPlayer)
    end 
end

function CHuodong:CheckOrgRewardFlag(oPlayer)
    local orgid  = oPlayer:GetOrgID()
    if not orgid or orgid == 0 then
        return 
    end
    local mConfig = self:GetConfigData("kaifu_org")
    local mRes1 = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orglevel"]
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local iOpenDay2 = mConfig["openday"]
    if iOpenDay >iOpenDay2 then
        return 
    end
    self:Dirty()
    local pid = oPlayer:GetPid()
    local iTime = (iOpenDay2 - iOpenDay+1)*24*60*60
    for iCnt , mInfo in pairs(mRes1) do
        local sFlag = string.format("kaifu_orgcnt_%s",iCnt)
        if oPlayer.m_oThisTemp:Query(sFlag,0) == 1 and (not (self.m_mOrgCnt[iCnt] and  extend.Array.find(self.m_mOrgCnt[iCnt],orgid))) then
            oPlayer.m_oThisTemp:Delete(sFlag)
            if self.m_mRewardInfo["orgcnt"][pid] then
                extend.Array.remove(self.m_mRewardInfo["orgcnt"][pid],sFlag)
            end
        end
        if oPlayer.m_oThisTemp:Query(sFlag,0) == 0 and self.m_mOrgCnt[iCnt] and  extend.Array.find(self.m_mOrgCnt[iCnt],orgid) then
            oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
            if not self.m_mRewardInfo["orgcnt"][pid] then
                self.m_mRewardInfo["orgcnt"][pid] = {}
            end
            table.insert(self.m_mRewardInfo["orgcnt"][pid],sFlag)
        end
    end
    for iLevel , mInfo in pairs(mRes2) do
        local sFlag = string.format("kaifu_orglevel_%s",iLevel)
        if oPlayer.m_oThisTemp:Query(sFlag,0) == 1 and (not (self.m_mOrgLevel[iLevel] and extend.Array.find(self.m_mOrgLevel[iLevel],orgid))) then
            oPlayer.m_oThisTemp:Delete(sFlag)
            if self.m_mRewardInfo["orglevel"][pid] then
                extend.Array.remove(self.m_mRewardInfo["orglevel"][pid],sFlag)
            end
        end
        if oPlayer.m_oThisTemp:Query(sFlag,0) == 0 and self.m_mOrgLevel[iLevel] and  extend.Array.find(self.m_mOrgLevel[iLevel],orgid) then
            oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
            if not self.m_mRewardInfo["orglevel"][pid] then
                self.m_mRewardInfo["orglevel"][pid] = {}
            end
            table.insert(self.m_mRewardInfo["orglevel"][pid],sFlag)
        end
    end
end

function CHuodong:CheckOrgRankReward(oPlayer)
    local orgobj = oPlayer:GetOrg()
    if not orgobj then
        return 
    end
    local orgid  = orgobj:OrgID()
    local pid = oPlayer:GetPid()
    local mConfig = self:GetConfigData("kaifu_org")
    local mRes1 = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orglevel"]
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local iOpenDay2 = mConfig["openday"]
    if iOpenDay >iOpenDay2 then
        return 
    end
    self:Dirty()
    local bSend = false
    for iCnt , mInfo in pairs(mRes1) do
        if not self.m_mOrgCnt[iCnt] then
            goto continue
        end
        if not extend.Array.find(self.m_mOrgCnt[iCnt],orgid) then
            goto continue
        end
        local iTime = (iOpenDay2 - iOpenDay+1)*24*60*60
        local sFlag = string.format("kaifu_orgcnt_%s",iCnt)
        if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 0 then
            goto continue
        end
        bSend = true
        oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
        if not self.m_mRewardInfo["orgcnt"][pid] then
            self.m_mRewardInfo["orgcnt"][pid] = {}
        end
        table.insert(self.m_mRewardInfo["orgcnt"][pid],sFlag)
        ::continue::
    end
    for iLevel , mInfo in pairs(mRes2) do
        if not self.m_mOrgLevel[iLevel] then
            goto continue
        end
        if not extend.Array.find(self.m_mOrgLevel[iLevel],orgid) then
            goto continue
        end
        local sFlag = string.format("kaifu_orglevel_%s",iLevel)
        local iTime = (iOpenDay2 - iOpenDay+1)*24*60*60
        if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 0 then
            goto continue
        end
        oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
        if not self.m_mRewardInfo["orglevel"][pid] then
            self.m_mRewardInfo["orglevel"][pid] = {}
        end
        table.insert(self.m_mRewardInfo["orglevel"][pid],sFlag)
        bSend = true
        ::continue::
    end
    if bSend then
        self:GS2CKaiFuRankReward(oPlayer)
    end
end

function CHuodong:GS2CKFTouxianRank(oPlayer)
    local mNet = {}
    local mTXData = {}
    local iShowTX = self:GetShowTX()
    for iLevel,mTouxian in pairs(self.m_mTouXian) do
        if iLevel ~= iShowTX then
            goto continue 
        end
        for pid,mInfo in pairs(mTouxian) do
            local mData = {}
            mData.pid = pid
            mData.name = mInfo.name
            mData.rank = mInfo.rank 
            mData.level  = iLevel
            table.insert(mTXData,mData)
        end
        ::continue::
    end

    mNet.touxianrank = mTXData
    oPlayer:Send("GS2CKFTouxianRank",mNet)
end

function CHuodong:GetOrglevelReward(oPlayer,iLevel)
    local pid = oPlayer:GetPid()
    local mRes1 = self:GetConfigData("kaifu_org")
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orglevel"]

    if not mRes2[iLevel] then
        return
    end
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local iOpenDay1 = mRes1["openday"]
    local iOpenDay2 = mRes2[iLevel]["openday"]
    if iOpenDay1 < iOpenDay then
        return
    end
    local orgobj = oPlayer:GetOrg()
    if not orgobj then
        return
    end
    local orgid = orgobj:OrgID()
    if not orgid or orgid == 0 then
        return
    end

    if not self.m_mOrgLevel[iLevel] then
        return
    end
    if not extend.Array.find(self.m_mOrgLevel[iLevel],orgid) then
        return
    end
    local sFlag = string.format("kaifu_orglevel_%s",iLevel)
    if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 1 then
        return
    end
    local iReward = mRes2[iLevel]["reward"]
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1010))
        return
    end
    local iTime = (iOpenDay1 - iOpenDay+1)*24*60*60
    self:Dirty()
    oPlayer.m_oThisTemp:Set(sFlag,2,iTime)
    if self.m_mRewardInfo["orglevel"][pid] then
        extend.Array.remove(self.m_mRewardInfo["orglevel"][pid],sFlag)
    end
    self:Reward(pid,iReward)
    self:GS2CKaiFuRankReward(oPlayer)
end

function CHuodong:GetOrgCntReward(oPlayer,iCnt)
    local pid = oPlayer:GetPid()
    local mRes1 = self:GetConfigData("kaifu_org")
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]

    if not mRes2[iCnt] then
        return
    end
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local iOpenDay1 = mRes1["openday"]
    local iOpenDay2 = mRes2[iCnt]["openday"]
    if iOpenDay1 < iOpenDay then
        return
    end
    local orgobj = oPlayer:GetOrg()
    if not orgobj then
        return
    end
    local orgid = orgobj:OrgID()
    if not orgid or orgid == 0 then
        return
    end
    if not self.m_mOrgCnt[iCnt] then
        return
    end
    if not extend.Array.find(self.m_mOrgCnt[iCnt],orgid) then
        return
    end
    local sFlag = string.format("kaifu_orgcnt_%s",iCnt)
    if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 1 then
        return
    end
    local iReward = mRes2[iCnt]["reward"]
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1010))
        return
    end
    local iTime = (iOpenDay1 - iOpenDay+1)*24*60*60
    self:Dirty()
    oPlayer.m_oThisTemp:Set(sFlag,2,iTime)
    if self.m_mRewardInfo["orgcnt"][pid] then
        extend.Array.remove(self.m_mRewardInfo["orgcnt"][pid],sFlag)
    end
    self:Reward(pid,iReward)
    self:GS2CKaiFuRankReward(oPlayer)
end

function CHuodong:OnUpgrade(oPlayer,iFromGrade, iToGrade)
    if not global.oToolMgr:IsSysOpen("KAIFUDIANLI", oPlayer,true) then 
        return false
    end
    local mConfig = self:GetConfigData("kaifu_grade")
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playergrade"]
    local iGrade
    for iSubGrade,_ in pairs(mRes) do
        if iSubGrade>iFromGrade and iSubGrade<=iToGrade then
            iGrade = iSubGrade
            break
        end
    end
    if not iGrade then
        return
    end
    local pid = oPlayer:GetPid()
    mRes = mRes[iGrade]
    if mConfig["openday"]<iOpenDay then
        return
    end
    local iCreateDay = get_dayno(oPlayer.m_iCreateTime)
    local iCurDay = get_dayno()
    if iCurDay-iCreateDay+1>mRes["openday"] then
        return
    end
    local sFlag = string.format("kaifu_grade_%s",iGrade)
    if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 0 then
        return
    end
    self:Dirty()
    local iTime =  (mConfig["openday"] - iOpenDay+1)*24*60*60
    oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
    if not self.m_mRewardInfo["playergrade"][pid] then
        self.m_mRewardInfo["playergrade"][pid] = {}
    end
    table.insert(self.m_mRewardInfo["playergrade"][pid],sFlag)
    self:GS2CKaiFuRankReward(oPlayer)
end

function CHuodong:GetUpGradeReward(oPlayer,iGrade)
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mConfig = self:GetConfigData("kaifu_grade")
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playergrade"]
    if not mRes[iGrade] then
        return
    end
    mRes = mRes[iGrade]
    local sFlag = string.format("kaifu_grade_%s",iGrade)
    if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 1 then
        return
    end
    local iReward = mRes["reward"]
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1010))
        return
    end
    self:Dirty()
    local iTime = (mConfig["openday"] - iOpenDay+1)*24*60*60
    oPlayer.m_oThisTemp:Set(sFlag,2,iTime)
    if self.m_mRewardInfo["playergrade"][pid] then
        extend.Array.remove(self.m_mRewardInfo["playergrade"][pid],sFlag)
    end
    self:Reward(oPlayer:GetPid(),iReward)
    self:GS2CKaiFuRankReward(oPlayer)
end

function CHuodong:OnScoreChange(oPlayer,iCurScore)
    local pid = oPlayer:GetPid()
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mConfig = self:GetConfigData("kaifu_score")
    if mConfig["openday"] < iOpenDay then
        return 
    end
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playerscore"]
    for iScore,mInfo in pairs(mRes) do
        if mInfo["openday"]<iOpenDay then
            goto continue
        end
        if iCurScore<iScore then
            goto continue
        end
        local sFlag = string.format("kaifu_score_%s",iScore)
        if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 0  then
            return
        end
        local iTime = (mConfig["openday"] - iOpenDay+1)*24*60*60
        self:Dirty()
        oPlayer.m_oThisTemp:Set(sFlag,1,iTime)
        if not self.m_mRewardInfo["playerscore"][pid] then
            self.m_mRewardInfo["playerscore"][pid] = {}
        end
        table.insert(self.m_mRewardInfo["playerscore"][pid],sFlag)
        self:GS2CKaiFuRankReward(oPlayer)
        ::continue::
    end
end

function CHuodong:GetScoreReward(oPlayer,iScore)
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mConfig = self:GetConfigData("kaifu_score")
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playerscore"]
    if not mRes[iScore] then
        return 
    end
    mRes = mRes[iScore]
    if mConfig["openday"]<iOpenDay then
        return
    end
    local sFlag = string.format("kaifu_score_%s",iScore)
    if oPlayer.m_oThisTemp:Query(sFlag,0) ~= 1  then
        return
    end
    local iReward = mRes["reward"]
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize()<global.oToolMgr:GetItemRewardCnt(self.m_sName,iReward) then
        global.oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1010))
        return false
    end
    self:Dirty()
    local iTime = (mConfig["openday"] - iOpenDay+1)*24*60*60
    oPlayer.m_oThisTemp:Set(sFlag,2,iTime)
    if self.m_mRewardInfo["playerscore"][pid] then
        extend.Array.remove(self.m_mRewardInfo["playerscore"][pid],sFlag)
    end
    self:Reward(oPlayer:GetPid(),iReward)
    self:GS2CKaiFuRankReward(oPlayer)
end

function CHuodong:PackOrgCntReward(oPlayer)
    local orgobj = oPlayer:GetOrg()
    local mConfig = self:GetConfigData("kaifu_org")
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mData = {}
    for iCnt ,mInfo in pairs(mRes2) do
        if mConfig["openday"] < iOpenDay then
            table.insert(mData,{flag = iCnt,reward = 3})
            goto continue
        end
        local sFlag = string.format("kaifu_orgcnt_%s",iCnt)
        local iRewardFlag = oPlayer.m_oThisTemp:Query(sFlag,0)
        if not orgobj then
            iRewardFlag=0
        end
        table.insert(mData,{flag = iCnt,reward = iRewardFlag})
        ::continue::
    end
    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})
    local mNet = {}
    mNet.rewarddata = mData
    mNet.endtime = iEndTime
    if orgobj then
        mNet.orgcnt = orgobj:GetMemberCnt()
    end
    return mNet
end

function CHuodong:PackOrgLevelReward(oPlayer)
    local orgobj = oPlayer:GetOrg()
    local mConfig = self:GetConfigData("kaifu_org")
    local mRes2 = res["daobiao"]["huodong"][self.m_sName]["orglevel"]
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mData = {}
    for iLevel ,mInfo in pairs(mRes2) do
        if mConfig["openday"] < iOpenDay then
            table.insert(mData,{flag = iLevel,reward = 3})
            goto continue
        end
        local sFlag = string.format("kaifu_orglevel_%s",iLevel)
        local iRewardFlag = oPlayer.m_oThisTemp:Query(sFlag,0)
        if not orgobj then
            iRewardFlag=0
        end
        table.insert(mData,{flag = iLevel,reward = iRewardFlag})
        ::continue::
    end

    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})
    
    local mNet = {}
    mNet.rewarddata = mData
    mNet.endtime = iEndTime
    if orgobj then
        mNet.orgcnt = orgobj:GetMemberCnt()
    end
    return mNet
end

function CHuodong:PackScoreReward(oPlayer)
    local mConfig = self:GetConfigData("kaifu_score")
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playerscore"]
    local mData = {}
    for iScore,mInfo in pairs(mRes) do
        if mConfig["openday"] < iOpenDay then
            table.insert(mData,{flag = iScore,reward = 3})
            goto continue
        end
        local sFlag = string.format("kaifu_score_%s",iScore)
        local iRewardFlag = oPlayer.m_oThisTemp:Query(sFlag,0)
        table.insert(mData,{flag = iScore,reward = iRewardFlag})
        ::continue::
    end
    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})
    local mNet = {}
    mNet.rewarddata = mData
    mNet.endtime = iEndTime
    return mNet
end

function CHuodong:PackGradeReward(oPlayer)
    local mConfig = self:GetConfigData("kaifu_grade")
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["playergrade"]
    local mData = {}
    for iGrade,mInfo in pairs(mRes) do
        if mConfig["openday"] < iOpenDay then
            table.insert(mData,{flag = iGrade,reward = 3})
            goto continue
        end
        local sFlag = string.format("kaifu_grade_%s",iGrade)
        local iRewardFlag = oPlayer.m_oThisTemp:Query(sFlag,0)
        table.insert(mData,{flag = iGrade,reward = iRewardFlag})
        ::continue::
    end

    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})

    local mNet = {}
    mNet.rewarddata = mData
    mNet.endtime = iEndTime
    return mNet
end

function CHuodong:PackTXEndTime(oPlayer)
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mConfig = self:GetConfigData("kaifu_touxian")
    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})
    return iEndTime
end

function CHuodong:PackSumEndTime(oPlayer)
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mConfig = self:GetConfigData("kaifu_summon")
    local iEndTime = 0
    local iLeftDay = mConfig["openday"] - iOpenDay
    
    local iTime = get_time() + (iLeftDay+1) * 3600 * 24
    local date = os.date("*t",iTime)
    iEndTime = os.time({year=date.year,month=date.month,day=date.day,hour=0,min=0,sec=0})

    return iEndTime
end

function CHuodong:GS2CKaiFuRankReward(oPlayer)
    if self.m_bAllRankEnd then return end
    local mNet = {}
    mNet.orgcnt = self:PackOrgCntReward(oPlayer)
    mNet.orglevel = self:PackOrgLevelReward(oPlayer)
    mNet.playerscore = self:PackScoreReward(oPlayer)
    mNet.playergrade = self:PackGradeReward(oPlayer)
    mNet.txendtime = self:PackTXEndTime(oPlayer)
    mNet.sumendtime = self:PackSumEndTime(oPlayer)
    mNet.createtime = oPlayer.m_iCreateTime
    oPlayer:Send("GS2CKaiFuRankReward",mNet)
   
end

function CHuodong:IsKaiFuAllRankEnd()
    local iOpenDay = global.oWorldMgr:GetOpenDays()
    local mRes = res["daobiao"]["huodong"][self.m_sName]["config"]
    self.m_bAllRankEnd = true
    for sKey, mConfig in pairs(mRes) do
        local iLeftDay = mConfig["openday"] - iOpenDay
        if iLeftDay >= 0 then
            self.m_bAllRankEnd = false
            break
        end
    end
end

function CHuodong:TestOp(iFlag, mArgs)
    local oChatMgr = global.oChatMgr
    local oNotifyMgr = global.oNotifyMgr
    local oWorldMgr = global.oWorldMgr
    local pid = mArgs[#mArgs]
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)

    local mCommand={
        "100 指令查看",
        "101刷新开服典礼排行版\nhuodongop kaifudianli 101",
        "102 清空头衔榜单\nhuodongop kaifudianli 102",
        "103 清空帮派人数和等级信息\nhuodongop kaifudianli 103",
        "104 清空领取帮派人数和等级奖励标记\nhuodongop kaifudianli 104",
        "105 清空等级奖励标记\nhuodongop kaifudianli 105",
        "106 清空战力奖励标记\nhuodongop kaifudianli 106",
        "107 奖励等级榜单\nhuodongop kaifudianli 107",
        "108 奖励实力榜单\nhuodongop kaifudianli 108",
        "109 奖励宠物榜单\nhuodongop kaifudianli 109",
        "110 奖励头衔榜单\nhuodongop kaifudianli 110",
        "111 奖励帮派榜单\nhuodongop kaifudianli 111",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 101 then
        if self:ValidPush() then
            --self:PushRank()
            global.oRankMgr:NewHour(get_daytime({anchor=1}))
            oNotifyMgr:Notify(pid,"推送成功")
        else
            oNotifyMgr:Notify(pid,string.format("推送失败 开服天数限制%s",global.oWorldMgr:GetOpenDays()))
        end
    elseif iFlag == 102 then
        self.m_mTouXian = {}
        oNotifyMgr:Notify(pid,"清空成功")
    elseif iFlag == 103 then
        self.m_mOrgCnt = {}
        self.m_mOrgLevel = {}
        oNotifyMgr:Notify(pid,"清空成功")
    elseif iFlag == 104 then
        local mRes = res["daobiao"]["huodong"][self.m_sName]["orgcnt"]
        for iCnt , mInfo in pairs(mRes) do
            local sFlag = string.format("kaifu_orgcnt_%s",iCnt)
            oPlayer.m_oThisTemp:Delete(sFlag)
        end
        local mRes = res["daobiao"]["huodong"][self.m_sName]["orglevel"]
        for iCnt , mInfo in pairs(mRes) do
            local sFlag = string.format("kaifu_orglevel_%s",iCnt)
            oPlayer.m_oThisTemp:Delete(sFlag)
        end
        if   self.m_mRewardInfo["orglevel"][pid] then
            self.m_mRewardInfo["orglevel"][pid] = nil
        end
        if   self.m_mRewardInfo["orgcnt"][pid] then
            self.m_mRewardInfo["orgcnt"][pid] = nil
        end
        oNotifyMgr:Notify(pid,"清空成功")
    elseif iFlag == 105 then
        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oThisTemp.m_mKeepList) do
            if string.find(sKey,"kaifu_grade_") then
                table.insert(lDel,sKey)
            end
        end
        if   self.m_mRewardInfo["playergrade"][pid] then
            self.m_mRewardInfo["playergrade"][pid] = nil
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oThisTemp:Delete(sKey)
        end
        oNotifyMgr:Notify(pid,"清空成功")
    elseif iFlag == 106 then
        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oThisTemp.m_mKeepList) do
            if string.find(sKey,"kaifu_score_") then
                table.insert(lDel,sKey)
            end
        end

        if   self.m_mRewardInfo["playerscore"][pid] then
            self.m_mRewardInfo["playerscore"][pid] = nil
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oThisTemp:Delete(sKey)
        end
        oNotifyMgr:Notify(pid,"清空成功")
    elseif iFlag == 107 then
        local sRankName= "kaifu_grade"
        local sFlag = string.format("query_rank_%s",sRankName)
        self:RemoteQueryRankReward(sRankName,sFlag)
    elseif iFlag == 108 then
        local sRankName= "kaifu_score"
        local sFlag = string.format("query_rank_%s",sRankName)
        self:RemoteQueryRankReward(sRankName,sFlag)
    elseif iFlag == 109 then
        local sRankName= "kaifu_summon"
        local sFlag = string.format("query_rank_%s",sRankName)
        self:RemoteQueryRankReward(sRankName,sFlag)
    elseif iFlag == 110 then
        self:RewardTXRank()
    elseif iFlag == 111 then
        local sRankName= "kaifu_org"
        local sFlag = string.format("query_rank_%s",sRankName)
        self:RemoteQueryRankReward(sRankName,sFlag)
    elseif iFlag == 201 then
        self.m_mRewardInfo = {}
        self:InitRewardInfo()
    elseif iFlag == 202 then 
        print(self.m_mRewardInfo)
    end
end

function OnRemoteQueryRankReward(mData)
    local oHD = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHD then
        oHD:RewardRank(mData)
    end
end
