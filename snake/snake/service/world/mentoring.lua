local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local defines = import(service_path("offline.defines"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))
local analylog = import(lualib_path("public.analylog"))

function NewMentoring()
    return CMentoring:New()
end

function NewMentoringTask(sKey)
    return CMentoringTask:New(sKey)
end

CMentoring = {}
CMentoring.__index = CMentoring
CMentoring.DB_KEY = "mentoring"
inherit(CMentoring, datactrl.CDataCtrl)

function CMentoring:New()
    local o = super(CMentoring).New(self)
    o.m_mMentor = {}
    o.m_mApprentice = {}
    o.m_mTaskList = {}
    return o
end

function CMentoring:Release()
    for sKey, oTask in pairs(self.m_mTaskList) do
        oTask:Release()
    end
    super(CMentoring).Release(self)
end

function CMentoring:LoadDb()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.DB_KEY},
    }
    gamedb.LoadDb("mentoring", "common", "DbOperate", mInfo,
    function (mRecord, mData)
        if not self:IsLoaded() then
             self:Load(mData.data)
             self:OnLoaded()
        end
    end)
end

function CMentoring:SaveDb()
    if not self:IsLoaded() then return end
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.DB_KEY},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("mentoring", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CMentoring:ConfigSaveFunc()
    self:ApplySave(function()
        local obj = global.oMentoring
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning(self.DB_KEY .. "save err: not obj")
        end
    end)
end

function CMentoring:_CheckSaveDb()
    assert(not is_release(self), "challenge save fail: has release")
    assert(self:IsLoaded(), "challenge save fail: is loading")
    self:SaveDb()
end

function CMentoring:AfterLoad()
    local mShare = {
        mentor = global.oMentoring.m_mMentor,
        apprentice = global.oMentoring.m_mApprentice,
    }
    interactive.Send(".recommend", "mentoring", "BuildShareObj", {share=mShare})
end

function CMentoring:Save()
    local mData = {}
    mData.mentor = self.m_mMentor
    mData.apprentice = self.m_mApprentice
    local mTaskList = {}
    for sKey, oTask in pairs(self.m_mTaskList) do
        mTaskList[sKey] = oTask:Save()
    end
    mData.task_list = mTaskList
    return mData
end

function CMentoring:Load(m)
    if not m then return end
    self.m_mMentor = m.mentor
    self.m_mApprentice = m.apprentice
    for sKey, mTask in pairs(m.task_list or {}) do
        local oTask = NewMentoringTask(sKey)
        oTask:Load(mTask)
        self.m_mTaskList[sKey] = oTask
    end
end

function CMentoring:MergeFrom(mFromData)
    if not mFromData or not next(mFromData) then
        return false, "mentoring option not data"
    end
    self:Dirty()
    for iPid, mMentor in pairs(mFromData.mentor) do
        self.m_mMentor[iPid] = mMentor
    end
    for iPid, mApprentice in pairs(mFromData.apprentice) do
        self.m_mApprentice[iPid] = mApprentice
    end
    for sKey, mTask in pairs(mFromData.task_list or {}) do
        local oTask = NewMentoringTask(sKey)
        oTask:Load(mTask)
        self.m_mTaskList[sKey] = oTask
    end
    return true
end

function CMentoring:Dirty(bUpdate)
    super(CMentoring).Dirty(self)
    if bUpdate then
        --self.m_oShareObj:Update()
    end
end

function CMentoring:AddMentorInfo(oPlayer, lOption)
    local iPid = oPlayer:GetPid()
    local mMentorInfo = self.m_mMentor[iPid] or {}
    mMentorInfo.option = lOption
    local oFriend = oPlayer:GetFriend()
    mMentorInfo.count = table_count(oFriend:GetApprentice())
    self.m_mMentor[iPid] = mMentorInfo
    self:Dirty()

    self:UpdateMentorInfo(iPid, mMentorInfo)
end

function CMentoring:UpdateApprentictCnt(iPid, iCnt)
    local mMentorInfo = self.m_mMentor[iPid]
    if not mMentorInfo then return end

    mMentorInfo.count = math.max(0, (mMentorInfo.count or 0) + iCnt)
    self.m_mMentor[iPid] = mMentorInfo
    self:Dirty()
    
    self:UpdateMentorInfo(iPid, mMentorInfo)
end

function CMentoring:AddApprentice(iPid, lOption)
    local mInfo = self.m_mApprentice[iPid] or {}
    mInfo.option = lOption
    self.m_mApprentice[iPid] = mInfo
    self:Dirty()

    self:UpdateApprenticeInfo(iPid, mInfo)
end

function CMentoring:DelApprentice(iPid)
    self.m_mApprentice[iPid] = nil
    self:Dirty()
    
    self:UpdateApprenticeInfo(iPid, nil)
end

function CMentoring:GetMentorByPid(iPid)
    return self.m_mMentor[iPid]
end

function CMentoring:GetApprenticeByPid(iPid)
    return self.m_mApprentice[iPid]
end

function CMentoring:GetTaskByKey(sKey)
    return self.m_mTaskList[sKey]
end

function CMentoring:AddTaskObj(sKey, oTask)
    self.m_mTaskList[sKey] = oTask
    self:Dirty()
end

function CMentoring:DelTaskObj(sKey)
    if self.m_mTaskList[sKey] then
        baseobj_delay_release(self.m_mTaskList[sKey])
        self.m_mTaskList[sKey] = nil
    end
end

--报名当师傅
function CMentoring:TryToBeMentor(oPlayer, lOptioin)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidToBeMentor(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end
    self:ToBeMentor(oPlayer, lOption)
end

function CMentoring:ValidToBeMentor(oPlayer)
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.mentor_grade_min then
        return 2003
    end
    local oFriend = oPlayer:GetFriend()
    if oFriend:FriendCount() >= oFriend:FriendsMaxCnt() then
        return 2006, {name=oPlayer:GetName()}
    end
    if oFriend:IsRefuseToggle() then
        return 2017, {name=oPlayer:GetName()}
    end
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) >= mConfig.apprentice_cnt then
        return 2007
    end
    local mPid = oFriend:GetMentor()
    if table_count(mPid) > 0 then
        return 2013, {name=oPlayer:GetName()}
    end
    local iRet = oFriend:GetMentoringCD() - get_time()
    if iRet > 0 then
        return 2009, {name=oPlayer:GetName(), hour=get_second2string(iRet)}
    end
    return 1
end

function CMentoring:ToBeMentor(oPlayer, lOption)
    local iPid = oPlayer:GetPid()
    assert(not self.m_mApprentice[iPid])
    self:AddMentorInfo(oPlayer, lOption)
    self:Notify(iPid, 1001)
    oPlayer:Set("mentor_option", lOption)

    analylog.LogSystemInfo(oPlayer, "tobementor", nil, {})
end

--取消报名
function CMentoring:CancelBeMentor(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mMentor[iPid] then
        self.m_mMentor[iPid] = nil
        self:Dirty()
        self:UpdateMentorInfo(iPid, nil)
        self:Notify(iPid, 1002)
    else
        self:Notify(iPid, 1003)
    end
    analylog.LogSystemInfo(oPlayer, "cancelbementor", nil, {})
end

--报名成为学徒
function CMentoring:TryToBeApprentice(oPlayer, lOption)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidToBeApprentice(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end
    self:ToBeApprentice(oPlayer, lOption)
end

function CMentoring:ValidToBeApprentice(oPlayer)
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.apprentice_grade_min then
        return 2004, {name=oPlayer:GetName()}
    end
    if oPlayer:GetGrade() > mConfig.apprentice_grade_max then
        return 2005, {name=oPlayer:GetName()}
    end
    if oPlayer:Query("mentor_id") then
        return 2015, {name=oPlayer:GetName()}
    end
    local oFriend = oPlayer:GetFriend()
    if oFriend:FriendCount() >= oFriend:FriendsMaxCnt() then
        return 2006, {name=oPlayer:GetName()}
    end
    if oFriend:IsRefuseToggle() then
        return 2017, {name=oPlayer:GetName()}
    end
    local mPid = oFriend:GetMentor()
    if table_count(mPid) >= mConfig.mentor_cnt then
        return 2008, {name=oPlayer:GetName()}
    end
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) > 0 then
        return 2014, {name=oPlayer:GetName()}
    end
    local iRet = oFriend:GetMentoringCD() - get_time()
    if iRet > 0 then
        return 2010, {name=oPlayer:GetName(), hour=get_second2string(iRet)}
    end
    return 1
end

function CMentoring:ToBeApprentice(oPlayer, lOption)
    local iPid = oPlayer:GetPid()
    assert(not self.m_mMentor[iPid])
    self:AddApprentice(iPid, lOption)
    self:Notify(iPid, 1004)
    oPlayer:Set("apprentice_option", lOption)
    self:TryFindMentor(oPlayer)
    analylog.LogSystemInfo(oPlayer, "tobeapprentice", nil, {})
end

--带徒弟拜师
function CMentoring:TryBuildRelationShip(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidBuildRelationShip(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    local oMentor, oApprentice = self:GetMentorAndApprentice(oPlayer)
    local oFriend1 = oMentor:GetFriend()
    local oFriend2 = oApprentice:GetFriend()
    local iPid1 = oMentor:GetPid()
    local iPid2 = oApprentice:GetPid()
    --师徒都在线，非异步
    if not oFriend1:HasFriend(iPid2) then
        global.oFriendMgr:AddFriend(oMentor, iPid2, {ignore_verify=true})
    end
    if not oFriend2:HasFriend(iPid1) then
        global.oFriendMgr:AddFriend(oApprentice, iPid1, {ignore_verify=true})
    end
    global.oFriendMgr:SetRelation(iPid1, iPid2, defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(iPid1, 1)
    self:Notify(iPid1, 2011, {name=oApprentice:GetName()})
    self:Notify(iPid2, 2012, {name=oMentor:GetName()})

    local sKey = self:EncodeKey(iPid1, iPid2)
    local oTask = NewMentoringTask(sKey)
    self:AddTaskObj(sKey, oTask)
    oTask:InitTask(oApprentice:GetGrade())
    oTask:RefreshMentorTask()
    if oTask:IsEmpty() then
        self:Notify(iPid1, 6002)
        self:Notify(iPid2, 6002)
    end
    oMentor:MarkGrow(43)
    oApprentice:MarkGrow(43)

    local mLogData = {
        mentor = oMentor:GetPid(),
        apprentice_id = oApprentice:GetPid(),
        action = "组队拜师",
    }
    record.log_db("mentoring", "build", mLogData)

    analylog.LogSystemInfo(oMentor, "releation_mentor", nil, {})
    analylog.LogSystemInfo(oApprentice, "releation_apprentice", nil, {})
end

function CMentoring:ValidBuildRelationShip(oPlayer)
    local iPid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return 2001
    end
    local iSize = oTeam:OnlineMemberSize()
    if iSize ~= 2 then
        return 2002
    end
    if oTeam:MemberSize() ~= 2 then
        return 2002
    end
   
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.mentor_grade_min then
        return 2003
    end
    local oMentor, oApprentice = self:GetMentorAndApprentice(oPlayer)
    if oApprentice:GetGrade() < mConfig.apprentice_grade_min then
        return 2004, {name=oApprentice:GetName()}
    end
    if oApprentice:GetGrade() > mConfig.apprentice_grade_max then
        return 2005, {name=oApprentice:GetName()}
    end
    if oApprentice:Query("mentor_id") then
        return 2015, {name=oApprentice:GetName()}
    end
    local oFriend1 = oMentor:GetFriend()
    if not oFriend1:HasFriend(oApprentice:GetPid()) and oFriend1:FriendCount() >= oFriend1:FriendsMaxCnt() then
        return 2006, {name=oMentor:GetName()}
    end
    if oFriend1:IsShield(oApprentice:GetPid()) then
        return 2016, {name=oApprentice:GetName()}
    end
    if oFriend1:IsRefuseToggle() then
        return 2017, {name=oMentor:GetName()}
    end
    local oFriend2 = oApprentice:GetFriend()
    if not oFriend2:HasFriend(oMentor:GetPid()) and oFriend2:FriendCount() >= oFriend2:FriendsMaxCnt() then
        return 2006, {name=oApprentice:GetName()}
    end
    if oFriend2:IsShield(oMentor:GetPid()) then
        return 2016, {name=oMentor:GetName()}
    end
    if oFriend2:IsRefuseToggle() then
        return 2017, {name=oApprentice:GetName()}
    end
    local mPid = oFriend1:GetApprentice()
    if table_count(mPid) >= mConfig.apprentice_cnt then
        return 2007
    end
    local mPid = oFriend1:GetMentor()
    if table_count(mPid) > 0 then
        return 2013, {name=oMentor:GetName()}
    end
    local mPid = oFriend2:GetMentor()
    if table_count(mPid) >= mConfig.mentor_cnt then
        return 2008, {name=oApprentice:GetName()}
    end
    local mPid = oFriend2:GetApprentice()
    if table_count(mPid) > 0 then
        return 2014, {name=oApprentice:GetName()}
    end
    local iRet = oFriend1:GetMentoringCD() - get_time()
    if iRet > 0 then
        return 2009, {name=oMentor:GetName(), hour=get_second2string(iRet)}
    end
    local iRet = oFriend2:GetMentoringCD() - get_time()
    if iRet > 0 then
        return 2010, {name=oApprentice:GetName(), hour=get_second2string(iRet)}
    end
    return 1
end

function CMentoring:GetMentorAndApprentice(oPlayer)
    local oTeam = oPlayer:HasTeam()
    local lMember = oTeam:GetTeamMember()
    return oPlayer, global.oWorldMgr:GetOnlinePlayerByPid(lMember[2])
end

--带徒弟出师
function CMentoring:TryApprenticeGrowup(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidApprenticeGrowup(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end

    local oMentor, oApprentice = self:GetMentorAndApprentice(oPlayer)
    local sKey = self:EncodeKey(oMentor:GetPid(), oApprentice:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    local iGrade = oApprentice:GetGrade()

    if 60 <= iGrade and iGrade <= 69 then
        local iPid = oMentor:GetPid()
        local iScore = oTask:GetEvalutaionScore()
        local sDesc, iRatio = oTask:GetEvalutaionDesc(iScore)
        local mReplace = {
            role = oApprentice:GetName(),
            score = iScore,
            desc = sDesc,
        }
        local mData = global.oToolMgr:GetTextData(7006, {"mentoring"})
        mData.sContent = global.oToolMgr:FormatColorString(mData.sContent, mReplace)
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:RespondApprenticeGrowup(oPlayer, mData)
        end)
    else
        global.oMentoring:RespondApprenticeGrowup(oPlayer, {answer=1, ignore=1})
    end
end

function CMentoring:RespondApprenticeGrowup(oPlayer, mData)
    if mData.answer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    if mData.ignore ~= 1 then
        local iRet, mReplace = self:ValidApprenticeGrowup(oPlayer)
        if iRet ~= 1 then
            self:Notify(iPid, iRet, mReplace)
            return
        end
    end
    local oMentor, oApprentice = self:GetMentorAndApprentice(oPlayer)
    local sKey = self:EncodeKey(oMentor:GetPid(), oApprentice:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return end

    global.oFriendMgr:ResetRelation(oMentor:GetPid(), oApprentice:GetPid(), defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(oMentor:GetPid(), -1)
    local sDesc, iRatio = oTask:GetEvalutaionDesc()
    self:DelTaskObj(sKey)
    safe_call(oTask.DoAllTaskReward, oTask)
    local mEnv = {argenv = {ratio = iRatio}}
    local sReason = "出师奖励"
    local mReward = self:GetGrowupReward()
    global.oRewardMgr:RewardByGroup(oMentor, "mentoring", mReward.mentor_reward_idx, mEnv)

    local iVal = mReward.mentor_xiayi*iRatio//100
    oMentor.m_oActiveCtrl:AddXiayiPoint(iVal, sReason, {force=1})
    self:Notify(oMentor:GetPid(), 6006, {val=iVal})

    self:StaticMentorCnt(oMentor, oApprentice:GetPid())
    global.oRewardMgr:RewardByGroup(oApprentice, "mentoring", mReward.apprentice_reward_idx, mEnv)

    local iVal = mReward.apprentice_xiayi*iRatio//100
    oApprentice.m_oActiveCtrl:AddXiayiPoint(iVal, sReason, {force=1})
    self:Notify(oApprentice:GetPid(), 6006, {val=iVal})

    local sName = oMentor:GetName()
    local mConfig = self:GetConfig()
    global.oTitleMgr:AddTitle(oApprentice:GetPid(), mConfig.apprentice_title, sName)
    oApprentice:Set("mentor_id", oMentor:GetPid())
    self:Notify(oMentor:GetPid(), 7007)
    self:Notify(oApprentice:GetPid(), 7008)

    local mLogData = {
        mentor = oMentor:GetPid(),
        apprentice_id = oApprentice:GetPid(),
        action = "普通",
    }
    record.log_db("mentoring", "growup", mLogData)

    analylog.LogSystemInfo(oApprentice, "releation_growup", nil, {})
end

function CMentoring:ValidApprenticeGrowup(oPlayer)
    local iPid = oPlayer:GetPid()
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        return 2001
    end
    local iSize = oTeam:OnlineMemberSize()
    if iSize ~= 2 then
        return 7001
    end
    if oTeam:MemberSize() ~= 2 then
        return 7001
    end
    local oMentor, oApprentice = self:GetMentorAndApprentice(oPlayer)
    local oFriend1 = oMentor:GetFriend()
    local oFriend2 = oApprentice:GetFriend()
    local mPid1 = oFriend1:GetApprentice()
    local mPid2 = oFriend2:GetApprentice()
    if mPid2[oMentor:GetPid()] then
        return 7003
    end
    if not mPid1[oApprentice:GetPid()] then
        return 7002
    end
    local mPid1 = oFriend1:GetMentor()
    local mPid2 = oFriend2:GetMentor()
    if mPid1[oApprentice:GetPid()] then
        return 7003
    end
    if not mPid2[oMentor:GetPid()] then
        return 7002
    end
    local sKey = self:EncodeKey(oMentor:GetPid(), oApprentice:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then
        return 7002
    end
    local mAllReward = oTask:GetAllReward()
    local mReward = mAllReward[#mAllReward]
    if oTask:GetProgress() < mReward.progress then
        return 7005
    end
    local mConfig = self:GetConfig()
    if oApprentice:GetGrade() < mConfig.apprentice_growup then
        return 7004
    end
    return 1
end

function CMentoring:StaticMentorCnt(oMentor, iPid)
    local mApprentice = oMentor:Query("apprentice", {})
    mApprentice[iPid] = get_time()
    oMentor:Set("apprentice", mApprentice)

    local iLen = table_count(mApprentice)
    local mTitleReward = self:GetTitleReward()
    local mReward = mTitleReward[iLen]
    if mReward and not oMentor.m_oTitleCtrl:GetTitleByTid(mReward.title) then
        global.oTitleMgr:AddTitle(oMentor:GetPid(), mReward.title)
    end
end

--强制出师
function CMentoring:TryForceApprenticeGrowup(oPlayer)
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetMentor()
    local iPid = oPlayer:GetPid()
    if table_count(mPid) > 0 then
        self:LoadProfileList(table_key_list(mPid), function(lProfile)
            global.oMentoring:ForceApprenticeGrowupByApprentice(iPid, lProfile)
        end)
        return
    end
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) > 0 then
        self:LoadProfileList(table_key_list(mPid), function(lProfile)
            global.oMentoring:ForceApprenticeGrowupByMentor(iPid, lProfile)
        end)
        return
    end
    self:Notify(oPlayer:GetPid(), 8001)
end

function CMentoring:ForceApprenticeGrowupByApprentice(iPid, lProfile)
    assert(#lProfile == 1)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oProfile = lProfile[1]
    local iTarget = oProfile:GetPid()
    local iRet = self:ValidForceApprenticeGrowupByApprentice(oPlayer, oProfile)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end
    --申请
    local mData = global.oToolMgr:GetTextData(8014, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:ForceApprenticeGrowupByApprentice2(oPlayer, iTarget, mData)
    end)
end

function CMentoring:ForceApprenticeGrowupByApprentice2(oPlayer, iTarget, mData)
    if mData.answer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:ForceApprenticeGrowupByApprentice3(iPid, o)
    end)
end

function CMentoring:ForceApprenticeGrowupByApprentice3(iPid, oProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iRet = self:ValidForceApprenticeGrowupByApprentice(oPlayer, oProfile)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    local sKey = self:EncodeKey(oProfile:GetPid(), iPid)
    local oTask = self:GetTaskByKey(sKey)
    local mConfig = self:GetConfig()
    oTask:SetApprenticeForceTime(mConfig.force_cd*60+get_time())

    self:Notify(iPid, 8016)
    self:SendMentoringMail(oProfile:GetPid(), 2062, {role = oPlayer:GetName()})

    local mLogData = {
        mentor = oProfile:GetPid(),
        apprentice_id = iPid,
        action = "徒弟申请出师",
    }
    record.log_db("mentoring", "growup", mLogData)
end

function CMentoring:ValidForceApprenticeGrowupByApprentice(oPlayer, oProfile)
    local iTarget = oProfile:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetMentor()
    if not mPid[iTarget] then
        return 8001
    end
    local mConfig = self:GetConfig()
    if oPlayer:GetGrade() < mConfig.apprentice_force_grade then
        return 8011
    end
    if get_time() - oProfile:GetLastOnlineTime() < mConfig.offline_time*60 then
        return 8012
    end
    local sKey = self:EncodeKey(iTarget, oPlayer:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then
        return 8001
    end
    if oTask:GetApprenticeForceTime() > 0 then
        return 8013
    end
    local mAllReward = oTask:GetAllReward()
    local mReward = mAllReward[#mAllReward]
    if oTask:GetProgress() < mReward.progress then
        return 7005
    end
    return 1
end

function CMentoring:ForceApprenticeGrowupByMentor(iPid, lProfile)
    assert(#lProfile <= 2)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lForce = {}
    for _, oProfile in ipairs(lProfile) do
        local iRet = self:ValidForceApprenticeGrowupByMentor(oPlayer, oProfile)
        if iRet == 1 then
            table.insert(lForce, {oProfile:GetPid(), oProfile:GetName()})
        end
    end
    if #lForce <= 0 then
        self:Notify(oPlayer:GetPid(), 8020)
        return
    end

    if #lForce >= 2 then
        local mData = global.oToolMgr:GetTextData(8006, {"mentoring"})
        mData.sCancle = lForce[1][2]
        mData.sConfirm = lForce[2][2]
        mData.close_btn = 0
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:ForceApprenticeGrowupByMentor4(oPlayer, lForce, mData)
        end)
    else
        local iTarget, _ = table.unpack(lForce[1])
        local mData = global.oToolMgr:GetTextData(8014, {"mentoring"})
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:ForceApprenticeGrowupByMentor2(oPlayer, iTarget, mData)
        end)
    end
end

function CMentoring:ForceApprenticeGrowupByMentor2(oPlayer, iTarget, mData)
    if mData.answer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:ForceApprenticeGrowupByMentor3(iPid, o)
    end)
end

function CMentoring:ForceApprenticeGrowupByMentor3(iPid, oProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iRet = self:ValidForceApprenticeGrowupByMentor(oPlayer, oProfile)
    if iRet ~= 1 then
        self:Notify(iPid, iRet)
        return
    end

    self:Notify(iPid, 8016)
    self:SendMentoringMail(oProfile:GetPid(), 2063, {role=oPlayer:GetName()})

    local sKey = self:EncodeKey(iPid, oProfile:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    local mConfig = self:GetConfig()
    oTask:SetMentorForceTime(mConfig.force_cd*60+get_time())

    local mLogData = {
        mentor = iPid,
        apprentice_id = oProfile:GetPid(),
        action = "师傅申请出师",
    }
    record.log_db("mentoring", "growup", mLogData)
end

function CMentoring:ForceApprenticeGrowupByMentor4(oPlayer, lForce, mData)
    if not lForce[mData.answer+1] then return end

    local iTarget, sName = table.unpack(lForce[mData.answer+1])
    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:ForceApprenticeGrowupByMentor3(iPid, o)
    end)
end

function CMentoring:ValidForceApprenticeGrowupByMentor(oPlayer, oProfile)
    local iTarget = oProfile:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    if not mPid[iTarget] then
        return 8001
    end
    local mConfig = self:GetConfig()
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    local iGrade = oTarget and oTarget:GetGrade() or oProfile:GetGrade()
    if iGrade < mConfig.apprentice_force_grade then
        return 8011
    end
    if get_time() - oProfile:GetLastOnlineTime() < mConfig.offline_time*60 then
        return 8012
    end
    local sKey = self:EncodeKey(oPlayer:GetPid(), iTarget)
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then
        return 8001
    end
    local mAllReward = oTask:GetAllReward()
    local mReward = mAllReward[#mAllReward]
    if oTask:GetProgress() < mReward.progress then
        return 7005
    end
    if oTask:GetMentorForceTime() > 0 then
        return 8013
    end
    return 1
end

function CMentoring:SureForceApprenticeGrowup(oPlayer)
    local oFriend = oPlayer:GetFriend()
    local iPid = oPlayer:GetPid()
    local mPid = oFriend:GetMentor()
    if table_count(mPid) > 0 then
        local iTarget, _ = next(mPid)
        self:SureForceApprenticeGrowupByApprentice(oPlayer, iTarget)
        return
    end
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) > 0 then
        self:LoadProfileList(table_key_list(mPid), function(lProfile)
            global.oMentoring:SureForceApprenticeGrowupByMentor(iPid, lProfile)
        end)
        return
    end
    self:Notify(oPlayer:GetPid(), 8017)
end

function CMentoring:SureForceApprenticeGrowupByApprentice(oPlayer, iTarget)
    local iRet, mReplace = self:ValidSureByApprentice(oPlayer, iTarget)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end
    local mData = global.oToolMgr:GetTextData(8015, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:SureForceApprenticeGrowupByApprentice2(oPlayer, iTarget, mData)
    end)
end

function CMentoring:SureForceApprenticeGrowupByApprentice2(oPlayer, iTarget, mData)
    local sKey = self:EncodeKey(iTarget, oPlayer:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return end

    if mData.answer ~= 1 then
        oTask:SetApprenticeForceTime(0)
        return
    end

    local iRet, mReplace = self:ValidSureByApprentice(oPlayer, iTarget)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end

    local sKey = self:EncodeKey(iTarget, oPlayer:GetPid())
    self:DelTaskObj(sKey)
    safe_call(oTask.DoAllTaskReward, oTask, oPlayer:GetPid())
    global.oFriendMgr:ResetRelation(iTarget, oPlayer:GetPid(), defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(iTarget, -1)

    local iPid = oPlayer:GetPid()
    local mReward = self:GetGrowupReward()
    local mEnv = {argenv = {ratio = 50}}
    global.oRewardMgr:RewardByGroup(oPlayer, "mentoring", mReward.apprentice_reward_idx, mEnv)
    local iVal = mReward.apprentice_xiayi//2
    oPlayer.m_oActiveCtrl:AddXiayiPoint(iVal, "强制出师", {force=1})
    self:Notify(oPlayer:GetPid(), 6006, {val=iVal})

    self:Notify(iPid, 8019)
    self:SendMentoringMail(iTarget, 2064, {role=oPlayer:GetName()})

    local mLogData = {
        mentor = iTarget,
        apprentice_id = oPlayer:GetPid(),
        action = "徒弟强制出师",
    }
    record.log_db("mentoring", "growup", mLogData)

    analylog.LogSystemInfo(oPlayer, "releation_growup", nil, {})
end

function CMentoring:ValidSureByApprentice(oPlayer, iTarget)
    local sKey = self:EncodeKey(iTarget, oPlayer:GetPid())
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return 8017 end

    local iForceTime = oTask:GetApprenticeForceTime()
    if iForceTime <= 0 then
        return 8017
    end
    local iRet = iForceTime - get_time()
    if iRet > 0 then
        return 8018, {time=get_second2string(iRet)}
    end
    return 1
end

function CMentoring:SureForceApprenticeGrowupByMentor(iPid, lProfile)
    assert(#lProfile <= 2)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lSure = {}
    for _, oProfile in ipairs(lProfile) do
        local iRet = self:ValidForceApprenticeGrowupByMentor(oPlayer, oProfile)
        if iRet == 8013 then
            table.insert(lSure, {oProfile:GetPid(), oProfile:GetName()})
        end
    end
    if #lSure <= 0 then
        self:Notify(oPlayer:GetPid(), 8020)
        return
    end

    if #lSure >= 2 then
        local mData = global.oToolMgr:GetTextData(8006, {"mentoring"})
        mData.sCancle = lSure[1][2]
        mData.sConfirm = lSure[2][2]
        mData.close_btn = 0
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:SureForceApprenticeGrowupByMentor4(oPlayer, lSure, mData)
        end)
    else
        local iTarget, _ = table.unpack(lSure[1])
        local mData = global.oToolMgr:GetTextData(8015, {"mentoring"})
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:SureForceApprenticeGrowupByMentor2(oPlayer, iTarget, mData)
        end)
    end
end

function CMentoring:SureForceApprenticeGrowupByMentor2(oPlayer, iTarget, mData)
    if mData.answer ~= 1 then return end

    local iRet, mReplace = self:ValidSureByMentor(oPlayer, iTarget)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end

    local mData = global.oToolMgr:GetTextData(8015, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:SureForceApprenticeGrowupByMentor3(oPlayer, iTarget, mData)
    end)
end

function CMentoring:SureForceApprenticeGrowupByMentor3(oPlayer, iTarget, mData)
    local sKey = self:EncodeKey(oPlayer:GetPid(), iTarget)
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return end

    if mData.answer ~= 1 then

        oTask:SetMentorForceTime(0)
        return
    end

    local iRet, mReplace = self:ValidSureByMentor(oPlayer, iTarget)
    if iRet ~= 1 then
        self:Notify(oPlayer:GetPid(), iRet, mReplace)
        return
    end

    local sKey = self:EncodeKey(oPlayer:GetPid(), iTarget)
    self:DelTaskObj(sKey)
    safe_call(oTask.DoAllTaskReward, oTask, oPlayer:GetPid())
    global.oFriendMgr:ResetRelation(oPlayer:GetPid(), iTarget, defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(oPlayer:GetPid(), -1)

    local iPid = oPlayer:GetPid()
    local mReward = self:GetGrowupReward()
    local mEnv = {argenv = {ratio = 50}}
    global.oRewardMgr:RewardByGroup(oPlayer, "mentoring", mReward.mentor_reward_idx, mEnv)
    local iVal = mReward.mentor_xiayi//2
    oPlayer.m_oActiveCtrl:AddXiayiPoint(iVal, "强制出师", {force=1})
    self:Notify(oPlayer:GetPid(), 6006, {val=iVal})
    self:StaticMentorCnt(oPlayer, iTarget)
    self:Notify(iPid, 8019)
    self:SendMentoringMail(iTarget, 2065, {role=oPlayer:GetName()})

    local mLogData = {
        mentor = oPlayer:GetPid(),
        apprentice_id = iTarget,
        action = "师傅强制出师",
    }
    record.log_db("mentoring", "growup", mLogData)
    analylog.LogSystemInfo(oPlayer, "releation_growup", nil, {})
end

function CMentoring:SureForceApprenticeGrowupByMentor4(oPlayer, lSure, mData)
    if not lSure[mData.answer+1] then return end

    local iTarget, sName = table.unpack(lSure[mData.answer+1])
    self:SureForceApprenticeGrowupByMentor2(oPlayer, iTarget, {answer=1})
end

function CMentoring:ValidSureByMentor(oPlayer, iTarget)
    local sKey = self:EncodeKey(oPlayer:GetPid(), iTarget)
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return 8017 end

    local iForceTime = oTask:GetMentorForceTime()
    if iForceTime <= 0 then
        return 8017
    end
    local iRet = iForceTime - get_time()
    if iRet > 0 then
        return 8018, {time=get_second2string(iRet)}
    end
    return 1
end

--解除师徒关系
function CMentoring:TryDismissRelationship(oPlayer)
    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) > 0 then
        self:LoadProfileList(table_key_list(mPid), function(lProfile)
            global.oMentoring:DismissRelationshipByMentor(iPid, lProfile)
        end)
        return
    end
    local mPid = oFriend:GetMentor()
    if table_count(mPid) > 0 then
        self:LoadProfileList(table_key_list(mPid), function(lProfile)
            global.oMentoring:DismissRelationshipByApprentice(iPid, lProfile)
        end)
        return
    end
    self:Notify(oPlayer:GetPid(), 8001)
end

function CMentoring:LoadProfileList(lPid, func)
    local iLen = #lPid
    local lProfile = {}
    for _, iPid in ipairs(lPid) do
        global.oWorldMgr:LoadProfile(iPid, function(o)
            table.insert(lProfile, o)
            if #lProfile >= iLen then
                safe_call(func, lProfile)
            end
        end)
    end
end

function CMentoring:DismissRelationshipByMentor(iPid, lProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iLen = #lProfile
    assert(iLen < 3)
    if iLen <= 0 then return end

    local mConfig = self:GetConfig()
    if iLen == 1 then
        local oProfile = lProfile[1]
        local iTarget = oProfile:GetPid()
        local iLastOnlineTime = oProfile:GetLastOnlineTime() 
        local mReplace = {name = oProfile:GetName()}
        local mData
        if get_time() - iLastOnlineTime < mConfig.offline_time*60 then
            mData = global.oToolMgr:GetTextData(8002, {"mentoring"})
            mData.sContent = global.oToolMgr:FormatColorString(mData.sContent, mReplace)
            mData = global.oCbMgr:PackConfirmData(nil, mData)
        else
            mData = global.oToolMgr:GetTextData(8005, {"mentoring"})
            mData.sContent = global.oToolMgr:FormatColorString(mData.sContent, mReplace)
            mData = global.oCbMgr:PackConfirmData(nil, mData)
        end
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:ResponseDismissRelationshipByMentor(oPlayer, iTarget, mData)
        end)
    else
        local lPid = {}
        for _, oProfile in ipairs(lProfile) do
            table.insert(lPid, {oProfile:GetPid(), oProfile:GetName()})
        end
        local mData = global.oToolMgr:GetTextData(8006, {"mentoring"})
        mData.sCancle = lPid[1][2]
        mData.sConfirm = lPid[2][2]
        mData.close_btn = 0
        mData = global.oCbMgr:PackConfirmData(nil, mData)
        global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
        function(oPlayer, mData)
            global.oMentoring:ResponseDismissRelationshipByMentor3(oPlayer, lPid, mData)
        end)
    end
end

function CMentoring:ResponseDismissRelationshipByMentor(oPlayer, iTarget, mData)
    if mData.answer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:ResponseDismissRelationshipByMentor2(iPid, o)
    end)
end

function CMentoring:ResponseDismissRelationshipByMentor2(iPid, oProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iTarget = oProfile:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    if not mPid[iTarget] then return end

    global.oFriendMgr:ResetRelation(iPid, iTarget, defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(iPid, -1)
    local sKey = self:EncodeKey(iTarget, iPid)
    self:DelTaskObj(sKey)

    local mConfig = self:GetConfig()
    local iLastOnlineTime = oProfile:GetLastOnlineTime() 
    local mReplace = {name=oProfile:GetName()}
    if get_time() - iLastOnlineTime < mConfig.offline_time*60 then
        oFriend:SetMentoringCD(get_time() + mConfig.mentor_cd*60)
        self:Notify(iPid, 8003, mReplace)
        self:UpdateRecommendData(oPlayer)
    else
        self:Notify(iPid, 8004, mReplace)
    end
    self:SendMentoringMail(iTarget, 2066, {role=oPlayer:GetName()})

    local mLogData = {
        mentor = iPid,
        apprentice_id = iTarget,
        action = "师傅解散关系",
    }
    record.log_db("mentoring", "dismiss", mLogData)
    analylog.LogSystemInfo(oPlayer, "releation_dismiss", nil, {})
end

function CMentoring:ResponseDismissRelationshipByMentor3(oPlayer, lPid, mData)
    if not lPid[mData.answer+1] then return end

    local iTarget, sName = table.unpack(lPid[mData.answer+1])
    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:DismissRelationshipByMentor(iPid, {o})
    end)
end

function CMentoring:DismissRelationshipByApprentice(iPid, lProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iLen = #lProfile
    assert(iLen == 1)

    local mConfig = self:GetConfig()
    local oProfile = lProfile[1]
    local iLastOnlineTime = oProfile:GetLastOnlineTime() 
    local mReplace = {name = oProfile:GetName()}
    local mData
    local iTarget = oProfile:GetPid()
    if get_time() - iLastOnlineTime < mConfig.offline_time*60 then
        mData = global.oToolMgr:GetTextData(8007, {"mentoring"})
    else
        mData = global.oToolMgr:GetTextData(8008, {"mentoring"})
        mData.sContent = global.oToolMgr:FormatColorString(mData.sContent, mReplace)
    end
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:ResponseDismissRelationshipByApprentice(oPlayer, iTarget, mData)
    end)
end

function CMentoring:ResponseDismissRelationshipByApprentice(oPlayer, iTarget, mData)
    if mData.answer ~= 1 then return end

    local iPid = oPlayer:GetPid()
    global.oWorldMgr:LoadProfile(iTarget, function(o)
        global.oMentoring:ResponseDismissRelationshipByApprentice2(iPid, o)
    end)
end

function CMentoring:ResponseDismissRelationshipByApprentice2(iPid, oProfile)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local iTarget = oProfile:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetMentor()
    if not mPid[iTarget] then return end

    global.oFriendMgr:ResetRelation(iTarget, iPid, defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(iTarget, -1)
    local sKey = self:EncodeKey(iTarget, iPid)
    self:DelTaskObj(sKey)

    local mConfig = self:GetConfig()
    local iLastOnlineTime = oProfile:GetLastOnlineTime() 
    local mReplace = {name=oProfile:GetName()}
    if get_time() - iLastOnlineTime < mConfig.offline_time*60 then
        oFriend:SetMentoringCD(get_time() + mConfig.apprentice_cd*60)
        self:Notify(iPid, 8009, mReplace)
        self:UpdateRecommendData(oPlayer)
    else
        self:Notify(iPid, 8010, mReplace)
    end
    self:SendMentoringMail(iTarget, 2066, {role=oPlayer:GetName()})

    local mLogData = {
        mentor = iTarget,
        apprentice_id = iPid,
        action = "徒弟解散关系",
    }
    record.log_db("mentoring", "dismiss", mLogData)
    analylog.LogSystemInfo(oPlayer, "releation_dismiss", nil, {})
end

--推荐师傅
function CMentoring:TryFindMentor(oPlayer)
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidFindMentor(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end
    local mArgs = {
        pid = iPid,
        school = oPlayer:GetSchool(),
    }
    interactive.Request(".recommend", "mentoring", "MatchMentor", mArgs,
    function(mRecord, mData)
        self:SendMentorList(iPid, mData.match_list)
    end)
end

function CMentoring:ValidFindMentor(oPlayer)
    local iPid = oPlayer:GetPid()
    if not self.m_mApprentice[iPid] then
        return 3001
    end
    return self:ValidToBeApprentice(oPlayer)
end

function CMentoring:SendMentorList(iPid, lMentor)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    if not lMentor or #lMentor <= 0 then
        self:Notify(iPid, 3002)
        return
    end
    local lPlayer = {}
    for _, mInfo in ipairs(lMentor) do
        local oMentor = global.oWorldMgr:GetOnlinePlayerByPid(mInfo.pid)
        if oMentor then
            table.insert(lPlayer, oMentor:PackSimpleInfo())
        end
    end
    oPlayer:Send("GS2CMentoringRecommendMentor", {mentor_list=lPlayer})
    oPlayer.m_lMentoringRecommend = lPlayer
end

--拜师界面直接拜师
function CMentoring:TryDirectBuildRelationship(oPlayer, iMentor)
    local iPid = oPlayer:GetPid()
    local oMentor = global.oWorldMgr:GetOnlinePlayerByPid(iMentor)
    if not oMentor then
        self:Notify(iPid, 4001)
        return
    end
    local iRet, mReplace = self:ValidToBeMentor(oMentor)
    if iRet ~= 1 then
        if iRet == 2007 then
            iRet = 4003
        end
        self:Notify(iPid, iRet, mReplace)
        return
    end
    local iRet, mReplace = self:ValidToBeApprentice(oPlayer)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end
    local oFriend1 = oMentor:GetFriend()
    local oFriend2 = oPlayer:GetFriend()
    if oFriend1:IsShield(iPid) then
        self:Notify(iPid, 2018, {name=oMentor:GetName()})
        return
    end
    if oFriend2:IsShield(iMentor) then
        self:Notify(iPid, 2016, {name=oMentor:GetName()})
        return
    end

    --师徒都在线，非异步
    if not oFriend1:HasFriend(iPid) then
        global.oFriendMgr:AddFriend(oMentor, iPid, {ignore_verify=true})
    end
    if not oFriend2:HasFriend(iMentor) then
        global.oFriendMgr:AddFriend(oPlayer, iMentor, {ignore_verify=true})
    end
    oPlayer.m_lMentoringRecommend = nil
    global.oFriendMgr:SetRelation(iMentor, iPid, defines.RELATION_MASTER, defines.RELATION_APPRENTICE)
    self:UpdateApprentictCnt(iMentor, 1)
    self:Notify(iMentor, 4002, {name=oPlayer:GetName()})
    self:Notify(iPid, 2012, {name=oMentor:GetName()})
    self:SendMentoringMail(iMentor, 2058, {role=oPlayer:GetName()})
    self:SendMentoringMail(iPid, 2059, {role=oMentor:GetName()})

    local sKey = self:EncodeKey(iMentor, iPid)
    local oTask = NewMentoringTask(sKey)
    self:AddTaskObj(sKey, oTask)
    oTask:InitTask(oPlayer:GetGrade())
    oTask:RefreshMentorTask()
    if oTask:IsEmpty() then
        self:Notify(iPid, 6002)
    end
    oMentor:MarkGrow(43)
    oPlayer:MarkGrow(43)

    local mLogData = {
        mentor = iMentor,
        apprentice_id = iPid,
        action = "界面拜师",
    }
    record.log_db("mentoring", "build", mLogData)

    analylog.LogSystemInfo(oMentor, "releation_mentor", nil, {})
    analylog.LogSystemInfo(oPlayer, "releation_apprentice", nil, {})
end

function CMentoring:UpdateRecommendData(oPlayer)
    --只匹配在线玩家
    local oFriend = oPlayer:GetFriend()
    local mArgs = {
        pid = oPlayer:GetPid(),
        ret_friend_cnt = oFriend:FriendsMaxCnt() - oFriend:FriendCount(),
        cd_time = oFriend:GetMentoringCD(),
        black_list = oFriend:GetBlackList(),
        school = oPlayer:GetSchool(),
    }
    interactive.Send(".recommend", "mentoring", "UpdateOnline", mArgs)
end

function CMentoring:UpdateMentorInfo(iPid, mInfo)
    local mArgs = {
        pid = iPid,
        info = mInfo,
    }
    interactive.Send(".recommend", "mentoring", "UpdateMentorInfo", mArgs)
end

function CMentoring:UpdateApprenticeInfo(iPid, mInfo)
    local mArgs = {
        pid = iPid,
        info = mInfo,
    }
    interactive.Send(".recommend", "mentoring", "UpdateApprenticeInfo", mArgs)
end

function CMentoring:NewHour5(oPlayer)
    self:OnLoginMentorTask(oPlayer)
end

function CMentoring:OnLogin(oPlayer, bReEnter)
    if oPlayer.m_lMentoringRecommend then
        local mNet = {mentor_list=oPlayer.m_lMentoringRecommend}
        oPlayer:Send("GS2CMentoringRecommendMentor", mNet)
    end
    self:UpdateRecommendData(oPlayer)
    self:OnLoginMentorTask(oPlayer)
end

function CMentoring:OnLogout(oPlayer)
    interactive.Send(".recommend", "mentoring", "UpdateOffline", {pid=oPlayer:GetPid()})
end

function CMentoring:OnUpgrade(oPlayer, iFromGrade)
    local iPid = oPlayer:GetPid()
    local mConfig = self:GetConfig()
    if not oPlayer:Query("apprentice_confirm") then
        for _, iGrade in ipairs(mConfig.grade_list) do
            if iFromGrade < iGrade and oPlayer:GetGrade() >= iGrade then
                self:GiveToBeApprenticeConfirm(oPlayer)
            end
        end
    end
    local iGrade = mConfig.mentor_grade_min
    if oPlayer:GetGrade() >= iGrade and self:GetApprenticeByPid(iPid) then
        self:DelApprentice(iPid)
        local oFriend = oPlayer:GetFriend()
        oFriend:SetMentoringCD(0)
        self:UpdateRecommendData(oPlayer)
    end
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetMentor()
    if iFromGrade < iGrade and oPlayer:GetGrade() >= iGrade and table_count(mPid) <= 0 and table_count(oFriend:GetApprentice()) < mConfig.apprentice_cnt then
        self:GiveToBeMentorConfirm(oPlayer)
    end
    
    assert(table_count(mPid) < 2)

    for iPid, _ in pairs(mPid) do
        local sKey = self:EncodeKey(iPid, oPlayer:GetPid())
        local oTask = self:GetTaskByKey(sKey)
        if oTask then
            oTask:SetApprenticeGrade(oPlayer:GetGrade())
            oTask:CheckGrowup()
            for _, iGrade in ipairs(mConfig.mentor_evalutaion) do
                if iFromGrade < iGrade and oPlayer:GetGrade() >= iGrade then
                    self:GiveMentorEvalutaion(oPlayer, sKey, iGrade)
                end
            end
            oTask:RefreshMentorTask()
        end
    end
end

function CMentoring:OnScoreChange(oPlayer, iScore)
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    for iPid, _ in pairs(mPid) do
        local oTask = self:GetTaskObjByType(oPlayer, 1, iPid)
        if oTask then
            oTask:RefreshMentorTask()
        end
    end
    local mPid= oFriend:GetMentor()
    for iPid, _ in pairs(mPid) do
        local oTask = self:GetTaskObjByType(oPlayer, 2, iPid)
        if oTask then
            oTask:RefreshMentorTask()
        end
    end
end

function CMentoring:ValidGiveConfirm(oPlayer)
    if self.m_mApprentice[oPlayer:GetPid()] then
        return false
    end
    local oFriend = oPlayer:GetFriend()
    if table_count(oFriend:GetMentor()) > 0 then
        return false
    end
    if oFriend:GetMentoringCD() > get_time() then
        return false
    end
    local mConfig = self:GetConfig()
    for iPid, mInfo in pairs(self.m_mMentor) do
        if (mInfo.count or 0) < mConfig.apprentice_cnt then
            return true
        end
    end
    return false
end

function CMentoring:GiveToBeApprenticeConfirm(oPlayer)
    if not self:ValidGiveConfirm(oPlayer) then
        return
    end
    local iPid = oPlayer:GetPid()
    local mData = global.oToolMgr:GetTextData(5001, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:RespondToBeApprenticeConfirm(oPlayer, mData)
    end)
end

function CMentoring:RespondToBeApprenticeConfirm(oPlayer, mData)
    if mData.answer == 1 then
        oPlayer:Set("apprentice_confirm", 1)
        local oNpc = global.oNpcMgr:GetGlobalNpc(5294)
        oNpc:ToBeApprentice(oPlayer)
    end
end

function CMentoring:GiveToBeMentorConfirm(oPlayer)
    local iPid = oPlayer:GetPid()
    if self.m_mMentor[iPid] then return end

    local mData = global.oToolMgr:GetTextData(5002, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        global.oMentoring:RespondToBeMentorConfirm(oPlayer, mData)
    end)
end

function CMentoring:RespondToBeMentorConfirm(oPlayer, mData)
    if mData.answer == 1 then
        local oNpc = global.oNpcMgr:GetGlobalNpc(5294)
        oNpc:ToBeMentor(oPlayer)
    end
end

--给出对师傅的评价
function CMentoring:GiveMentorEvalutaion(oPlayer, sKey, iGrade)
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return end

    local mEvalutaion = oTask:GetEvalutaion()
    if mEvalutaion[iGrade] then return end

    local iPid = oPlayer:GetPid()
    local mNet = {
        grade = iGrade,
    }
    global.oCbMgr:SetCallBack(iPid, "GS2CMentorEvalutaion", mNet, nil,
    function(oPlayer, mData)
        global.oMentoring:RespondGiveMentorEvalutaion(oPlayer, mData, sKey, iGrade)
    end)
end

function CMentoring:RespondGiveMentorEvalutaion(oPlayer, mData, sKey, iGrade)
    local oTask = self:GetTaskByKey(sKey)
    if not oTask then return end

    local mEvalutaion = oTask:GetEvalutaion()
    if mEvalutaion[iGrade] then return end

    assert(mData.answer>0 and mData.answer<4)
    oTask:SetEvalutaion(iGrade, 125-25*mData.answer)
end

function CMentoring:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = global.oToolMgr:GetTextData(iChat, {"mentoring"})
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CMentoring:SendMentoringMail(iPid, iMail, mReplace, mReward)
    local mMail, sName = global.oMailMgr:GetMailInfo(iMail)
    if mReplace then
        mMail.context = global.oToolMgr:FormatColorString(mMail.context, mReplace)
    end
    global.oMailMgr:SendMailNew(0, sName, iPid, mMail, mReward)
end

function CMentoring:GetConfig()
    return res["daobiao"]["mentoring"]["config"][1]
end

function CMentoring:GetGrowupReward()
    return res["daobiao"]["mentoring"]["growup_reward"][1]
end

function CMentoring:GetTitleReward()
    return res["daobiao"]["mentoring"]["title_reward"]
end

function CMentoring:EncodeKey(iMentor, iApprentice)
    return iMentor .. "|" .. iApprentice
end

function CMentoring:DecodeKey(sKey)
    return table.unpack(split_string(sKey, "|", tonumber))
end

function CMentoring:AddTaskCnt(oLeader, iTask, iCnt, sReason)
    local oTeam = oLeader:HasTeam()
    if not oTeam then return end

    local mApprentice2Mentor = {}
    local lPlayer = {}
    for _, oMem in ipairs(oTeam:GetMember()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            local oFriend = oPlayer:GetFriend()
            local mPid = oFriend:GetApprentice()
            for iPid, _ in pairs(mPid) do
                mApprentice2Mentor[iPid] = oMem.m_ID
            end
            table.insert(lPlayer, oPlayer)
        end
    end
    for _, oPlayer in ipairs(lPlayer) do
        if mApprentice2Mentor[oPlayer:GetPid()] then
            local iApprentice = oPlayer:GetPid()
            local iMentor = mApprentice2Mentor[iApprentice]
            local sKey = self:EncodeKey(iMentor, iApprentice)
            local oTask = self:GetTaskByKey(sKey)
            if oTask then
                local mAllTask = oTask:GetAllTask()
                local mTask = mAllTask[iTask]
                if not mTask then
                    goto continue
                end
                oTask:AddTaskCnt(iTask, iCnt, sReason)
                if mTask.step and mTask.step > 0 then
                    oTask:AddStepResultCnt(iMentor, mTask.step, iCnt)
                    oTask:AddStepResultCnt(iApprentice, mTask.step, iCnt)
                end
                oTask:RefreshMentorTask()
                ::continue::
            end
        end
    end
end

function CMentoring:AddTaskCntByKSData(mData)
    local iMentor, iApprentice = mData.mentor, mData.apprentice
    local sKey = self:EncodeKey(iMentor, iApprentice)
    local oTask = self:GetTaskByKey(sKey)
    if oTask then
        local iTask = mData.task
        local mAllTask = oTask:GetAllTask()
        local mTask = mAllTask[iTask]
        if not mTask then return end

        local iCnt = mData.cnt
        local sReason = mData.reason
        oTask:AddTaskCnt(iTask, iCnt, sReason)
        if mTask.step and mTask.step > 0 then
            oTask:AddStepResultCnt(iMentor, mTask.step, iCnt)
            oTask:AddStepResultCnt(iApprentice, mTask.step, iCnt)
        end
    end
end

function CMentoring:AddStepResultCnt(oLeader, iStep, iCnt)
    local oTeam = oLeader:HasTeam()
    if not oTeam then return end

    local mApprentice2Mentor = {}
    local lPlayer = {}
    for _, oMem in ipairs(oTeam:GetMember()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(oMem.m_ID)
        if oPlayer then
            local oFriend = oPlayer:GetFriend()
            local mPid = oFriend:GetApprentice()
            for iPid, _ in pairs(mPid) do
                mApprentice2Mentor[iPid] = oMem.m_ID
            end
            table.insert(lPlayer, oPlayer)
        end
    end
    for _, oPlayer in ipairs(lPlayer) do
        if mApprentice2Mentor[oPlayer:GetPid()] then
            local iApprentice = oPlayer:GetPid()
            local iMentor = mApprentice2Mentor[iApprentice]
            local sKey = self:EncodeKey(iMentor, iApprentice)
            local oTask = self:GetTaskByKey(sKey)
            if oTask then
                oTask:AddStepResultCnt(iMentor, iStep, iCnt)
                oTask:AddStepResultCnt(iApprentice, iStep, iCnt)
                oTask:RefreshMentorTask()
                ::continue::
            end
        end
    end
end

function CMentoring:AddStepResultCntByKSData(mData)
    local iMentor, iApprentice = mData.mentor, mData.apprentice
    local sKey = self:EncodeKey(iMentor, iApprentice)
    local oTask = self:GetTaskByKey(sKey)
    if oTask then
        local iStep = mData.step
        local iCnt = mData.cnt
        oTask:AddStepResultCnt(iMentor, iStep, iCnt)
        oTask:AddStepResultCnt(iApprentice, iStep, iCnt)
    end
end

function CMentoring:OnLoginMentorTask(oPlayer)
    local iPid = oPlayer:GetPid()
    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    if table_count(mPid) > 0 then
        for iTarget, _ in pairs(mPid) do
            local sKey = self:EncodeKey(iPid, iTarget)
            local oTask = self:GetTaskByKey(sKey)
            if oTask then
                oTask:RefreshMentorTask(iPid)
            end
        end
    end
    local mPid = oFriend:GetMentor()
    if table_count(mPid) > 0 then
        for iTarget, _ in pairs(mPid) do
            local sKey = self:EncodeKey(iTarget, iPid)
            local oTask = self:GetTaskByKey(sKey)
            if oTask then
                oTask:RefreshMentorTask(iPid)
            end
        end
    end
end

function CMentoring:MentoringTaskReward(oPlayer, iType, iTarget, idx)
    local oTask = self:GetTaskObjByType(oPlayer, iType, iTarget)
    if not oTask then return end

    local iPid = oPlayer:GetPid()
    local mReward = oTask:GetRewardCnt(iPid)
    if mReward[idx] then return end

    local mAllReward = oTask:GetAllReward()
    local mReward = mAllReward[idx]
    if not mReward then return end

    if oTask:GetProgress() >= mReward.progress then
        oTask:AddRewardCnt(iPid, idx, 1)
        global.oRewardMgr:RewardByGroup(oPlayer, "mentoring", mReward.reward_idx)
        oTask:RefreshMentorTask(iPid)
    end
end

function CMentoring:MentorStepResultReward(oPlayer, iType, iTarget, idx)
    local oTask = self:GetTaskObjByType(oPlayer, iType, iTarget)
    if not oTask then return end

    local mAllStep = oTask:GetAllStepResult()
    local mStep = mAllStep[idx]
    if not mStep then return end

    local iPid = oPlayer:GetPid()
    local iRet, mReplace = self:ValidGetStepReward(oPlayer, oTask, idx)
    if iRet ~= 1 then
        self:Notify(iPid, iRet, mReplace)
        return
    end
    local iPoint = 0
    if iType == 1 then
        iPoint = mStep.mentor_xiayi_point
    else
        iPoint = mStep.apprentice_xiayi_point
    end
    local sReason = "师徒教学成果"..idx
    oTask:SetStepResultRewarded(iPid, idx, 1)
    oPlayer.m_oActiveCtrl:AddXiayiPoint(iPoint, sReason, {force=1})
    self:Notify(oPlayer:GetPid(), 6006, {val=iPoint})
    oTask:RefreshMentorTask(iPid)
end

function CMentoring:ValidGetStepReward(oPlayer, oTask, idx)
    local mAllStep = oTask:GetAllStepResult()
    local mStep = mAllStep[idx]
    if not mStep then
        return 6005
    end
    local iPid = oPlayer:GetPid()
    local iStatus = table_get_depth(oTask:GetStepResult(), {iPid, idx, "status"})
    if iStatus == -1 then
        return 6003
    end
    if iStatus == 1 then
        return 6004
    end
    if mStep.grade and mStep.grade > 0 then
        if not oTask:GradeJudge(mStep.grade) then
            return 6005
        end
    end
    if mStep.cnt and mStep.cnt > 0 then
        local iCnt = table_get_depth(oTask:GetStepResult(), {iPid, idx, "cnt"})
        if (iCnt or 0) < mStep.cnt then
            return 6005
        end
    end
    return 1
end

function CMentoring:SetStepResult(iPid, iTarget, idx, iVal)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oFriend = oPlayer:GetFriend()
    local mPid = oFriend:GetApprentice()
    if mPid[iTarget] then
        local sKey = self:EncodeKey(iPid, iTarget)
        local oTask = self:GetTaskByKey(sKey)
        if oTask then
            oTask:SetStepResultCnt(iPid, idx, iVal)
            oTask:RefreshMentorTask(iPid)
        end
    end

    local mPid = oFriend:GetMentor()
    if mPid[iTarget] then
        local sKey = self:EncodeKey(iTarget, iPid)
        local oTask = self:GetTaskByKey(sKey)
        if oTask then
            oTask:SetStepResultCnt(iPid, idx, iVal)
            oTask:RefreshMentorTask(iPid)
        end
    end
end

function CMentoring:GetTaskObjByType(oPlayer, iType, iTarget)
    local oTask
    if iType == 1 then          --oPlayer 为师傅
        local oFriend = oPlayer:GetFriend()
        local mPid = oFriend:GetApprentice()
        if not mPid[iTarget] then return end

        local sKey = self:EncodeKey(oPlayer:GetPid(), iTarget)
        oTask = self:GetTaskByKey(sKey)
    else
        local oFriend = oPlayer:GetFriend()
        local mPid = oFriend:GetMentor()
        if not mPid[iTarget] then return end

        local sKey = self:EncodeKey(iTarget, oPlayer:GetPid())
        oTask = self:GetTaskByKey(sKey)
    end
    return oTask
end

function CMentoring:TestOp(oMaster, iFlag, mArgs)
    if iFlag == 100 then
        global.oNotifyMgr:Notify(oMaster:GetPid(), [[
        101 - 删除冷却时间
        102 - 师徒一起完成任务 {task=1,cnt=2}
        103 - 设置进度 {progress=100}
        104 - 删除拜师记录
        105 - 刷新任务
        106 - 清空徒弟登记信息
        107 - 查看已登记信息
        ]])
    elseif iFlag == 101 then
        local oFriend = oMaster:GetFriend()
        oFriend:SetMentoringCD(0)
        self:UpdateRecommendData(oMaster)
        global.oNotifyMgr:Notify(oMaster:GetPid(), "删除成功")
    elseif iFlag == 102 then
        if not mArgs.task or not mArgs.cnt then
            global.oNotifyMgr:Notify(oMaster:GetPid(), "参数不完整")
            return
        end
        local oFriend = oMaster:GetFriend()
        local mPid = oFriend:GetApprentice()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 1, iPid)
            if oTask then
                oTask:AddTaskCnt(mArgs.task, mArgs.cnt, "gm")
                oTask:RefreshMentorTask()
            end
        end
        local mPid= oFriend:GetMentor()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 2, iPid)
            if oTask then
                oTask:AddTaskCnt(mArgs.task, mArgs.cnt, "gm")
                oTask:RefreshMentorTask()
            end
        end
    elseif iFlag == 103 then
        if not mArgs.progress then
            global.oNotifyMgr:Notify(oMaster:GetPid(), "参数不完整")
            return
        end
        local oFriend = oMaster:GetFriend()
        local mPid = oFriend:GetApprentice()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 1, iPid)
            if oTask then
                oTask:AddProgress(mArgs.progress)
                oTask:RefreshMentorTask()
            end
        end
        local mPid= oFriend:GetMentor()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 2, iPid)
            if oTask then
                oTask:AddProgress(mArgs.progress)
                oTask:RefreshMentorTask()
            end
        end
    elseif iFlag == 104 then
        oMaster:Set("mentor_id", nil)
        local mConfig = self:GetConfig()
        oMaster:RemoveTitles({mConfig.apprentice_title})
        global.oNotifyMgr:Notify(oMaster:GetPid(), "已删除")
    elseif iFlag == 105 then
        local oFriend = oMaster:GetFriend()
        local mPid = oFriend:GetApprentice()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 1, iPid)
            if oTask then
                oTask.m_mTask = oTask:RefreshTask()
                oTask:RefreshMentorTask()
            end
        end
        local mPid= oFriend:GetMentor()
        for iPid, _ in pairs(mPid) do
            local oTask = self:GetTaskObjByType(oMaster, 2, iPid)
            if oTask then
                oTask.m_mTask = oTask:RefreshTask()
                oTask:RefreshMentorTask()
            end
        end
    elseif iFlag == 106 then
        self.m_mApprentice[oMaster:GetPid()] = nil
    elseif iFlag == 107 then
        local lMentor, lApprentice = {}, {}
        for iPid, _ in pairs(self.m_mMentor) do
            table.insert(lMentor, tostring(iPid))
        end
        for iPid, _ in pairs(self.m_mApprentice) do
            table.insert(lApprentice, iPid)
        end
        local sMsg = "登记师傅id:" .. table.concat(lMentor, "、")
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
        local sMsg = "登记徒弟id:" .. table.concat(lApprentice, "、")
        global.oChatMgr:HandleMsgChat(oMaster, sMsg)
    end
end






----------------教学考核--------------
CMentoringTask = {}
CMentoringTask.__index = CMentoringTask
inherit(CMentoringTask, datactrl.CDataCtrl)

function CMentoringTask:New(sKey)
    local o = super(CMentoringTask).New(self)
    o.m_sKey = sKey
    o.m_mTask = {}
    o.m_iDayNo = 0
    o.m_iApprenticeGrade = 0
    o.m_iProgress = 0
    o.m_mReward = {}
    o.m_mStepResult = {}
    o.m_mEvalutaion = {}
    o.m_iNotify = 0
    o.m_iApprenticeForceTime = 0
    o.m_iMentorForceTime = 0
    o.m_iStartGrade = 0
    return o
end

function CMentoringTask:Release()
    super(CMentoringTask).Release(self)
end

function CMentoringTask:InitTask(iGrade)
    self:SetApprenticeGrade(iGrade)
    self:Validate()
    self:InitStepResult(iGrade)
    self.m_iStartGrade = iGrade
    self:Dirty()
end

function CMentoringTask:Save()
    local mSave = {}
    mSave.task = self.m_mTask
    mSave.apprentice_grade = self.m_iApprenticeGrade
    mSave.dayno = self.m_iDayNo
    mSave.progress = self.m_iProgress
    mSave.reward = self.m_mReward
    mSave.step_result = self.m_mStepResult
    mSave.evalutaion = self.m_mEvalutaion
    mSave.notify = self.m_iNotify
    mSave.apprentice_forcetime = self.m_iApprenticeForceTime
    mSave.mentor_forcetime = self.m_iMentorForceTime
    mSave.start_grade = self.m_iStartGrade
    return mSave
end

function CMentoringTask:Load(m)
    if not m then return end

    self.m_iApprenticeGrade = m.apprentice_grade or 0
    self.m_iDayNo = m.dayno or get_morningdayno()
    self.m_mTask = m.task or {}
    self.m_iProgress = m.progress or 0
    self.m_mReward = m.reward or {}
    self.m_mStepResult = m.step_result or {}
    self.m_mEvalutaion = m.evalutaion or {}
    self.m_iNotify = m.notify or 0
    self.m_iApprenticeForceTime = m.apprentice_forcetime or 0
    self.m_iMentorForceTime = m.mentor_forcetime or 0
    self.m_iStartGrade = m.start_grade or 0
end

function CMentoringTask:Dirty()
    global.oMentoring:Dirty()
end

function CMentoringTask:IsEmpty()
    self:Validate()
    return table_count(self.m_mTask) <= 0
end

function CMentoringTask:SetApprenticeGrade(iGrade)
    self.m_iApprenticeGrade = iGrade
    self:Dirty()
end

function CMentoringTask:AddProgress(iAdd)
    self.m_iProgress = self.m_iProgress + iAdd
    self:Dirty()

    self:CheckGrowup()
end

--出师判断
function CMentoringTask:CheckGrowup()
    if self.m_iNotify >= 1 then return end

    local mConfig = global.oMentoring:GetConfig()
    if self.m_iApprenticeGrade < mConfig.apprentice_growup then
        return
    end
    local mAllReward = self:GetAllReward()
    local mReward = mAllReward[#mAllReward]
    if self:GetProgress() < mReward.progress then
        return
    end
    self.m_iNotify = 1
    self:Dirty()

    local iMentor, iApprentice = global.oMentoring:DecodeKey(self.m_sKey)
    global.oWorldMgr:LoadProfile(iApprentice, function(oProfile)
        local mReplace = {role=oProfile:GetName()}
        global.oMentoring:SendMentoringMail(iMentor, 2060, mReplace)
        global.oMentoring:SendMentoringMail(iApprentice, 2061)
    end)
end

function CMentoringTask:GetProgress()
    return self.m_iProgress
end

function CMentoringTask:Validate()
    if self.m_iDayNo ~= get_morningdayno() then
        self.m_mTask = {}
        self:Dirty()
        self.m_mTask = self:RefreshTask()
        self.m_iDayNo = get_morningdayno()
    end
end

function CMentoringTask:RefreshTask()
    local lChoose = {}
    for iTask, mInfo in pairs(self:GetAllTask()) do
        if mInfo.open_key ~= "" then
            if not global.oToolMgr:IsSysOpen(mInfo.open_key) then
                goto continue
            end
            local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade(mInfo.open_key)
            if self.m_iApprenticeGrade < iOpenLevel then
                goto continue
            end
        elseif self.m_iApprenticeGrade < mInfo.open_level then
            goto continue
        end
        table.insert(lChoose, iTask)
        ::continue::
    end
    local mConfig = global.oMentoring:GetConfig()
    local lTask = extend.Random.random_size(lChoose, mConfig.task_cnt)
    local mTask = {}
    for _, iTask in pairs(lTask) do
        mTask[iTask] = 0
    end
    return mTask
end

function CMentoringTask:AddTaskCnt(iTask, iCnt, sReason)
    self:Validate()

    local mAllTask = self:GetAllTask()
    if not mAllTask[iTask] then return end

    if not self.m_mTask[iTask] then return end

    self:Dirty()
    self.m_mTask[iTask] = self.m_mTask[iTask] + iCnt
    self:OnAddTaskCnt(iTask, sReason)
end

function CMentoringTask:OnAddTaskCnt(iTask, sReason)
    local mAllTask = self:GetAllTask()
    if self.m_mTask[iTask] == mAllTask[iTask].done_cnt then
        self:AddProgress(mAllTask[iTask].progress)

        local iMentor, iApprentice = global.oMentoring:DecodeKey(self.m_sKey)
        for _, iPid in ipairs({iMentor, iApprentice}) do
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if oPlayer then
                local mReplace = {val=mAllTask[iTask].xiayi_point}
                global.oMentoring:Notify(iPid, 6001, mReplace)
                oPlayer.m_oActiveCtrl:AddXiayiPoint(mAllTask[iTask].xiayi_point, sReason, {force=1})
            end
        end
    end
end

function CMentoringTask:GetTaskCnt()
    self:Validate()
    return self.m_mTask
end

function CMentoringTask:GetRewardCnt(iPid)
    return self.m_mReward[iPid] or {}
end

function CMentoringTask:AddRewardCnt(iPid, idx, iAdd)
    self:Dirty()
    local iCurr = table_get_depth(self.m_mReward, {iPid, idx}) or 0
    table_set_depth(self.m_mReward, {iPid}, idx, iCurr+iAdd)
end

-----------教学成果----------
function CMentoringTask:InitStepResult(iGrade)
    self:Dirty()
    local iMentor, iApprentice = global.oMentoring:DecodeKey(self.m_sKey)
    self.m_mStepResult = {
        [iMentor] = {},
        [iApprentice] = {},
    }
    local mAllStep = self:GetAllStepResult()
    for idx, mStep in pairs(mAllStep) do
        if mStep.grade and mStep.grade > 0 then
            if self:GradeJudge(mStep.grade) then
                table_set_depth(self.m_mStepResult, {iMentor, idx}, "status", -1)
                table_set_depth(self.m_mStepResult, {iApprentice, idx}, "status", -1)
            end
        end
    end
    local oMentor = global.oWorldMgr:GetOnlinePlayerByPid(iMentor)
    if oMentor then
        local oFriend = oMentor:GetFriend()
        local iDegree = oFriend:GetFriendDegree(iApprentice)
        table_set_depth(self.m_mStepResult, {iMentor, 9}, "cnt", iDegree)
    end
    local oApprentice = global.oWorldMgr:GetOnlinePlayerByPid(iApprentice)
    if oApprentice then
        local oFriend = oApprentice:GetFriend()
        local iDegree = oFriend:GetFriendDegree(iMentor)
        table_set_depth(self.m_mStepResult, {iApprentice, 9}, "cnt", iDegree)
    end
end

function CMentoringTask:GetStepResult()
    return self.m_mStepResult
end

function CMentoringTask:SetStepResultRewarded(iPid, idx, iVal)
    table_set_depth(self.m_mStepResult, {iPid, idx}, "status", iVal)
    self:Dirty()
end

function CMentoringTask:AddStepResultCnt(iPid, idx, iVal)
    local iCurr = table_get_depth(self.m_mStepResult, {iPid, idx, "cnt"}) or 0
    table_set_depth(self.m_mStepResult, {iPid, idx}, "cnt", iVal+iCurr)
    self:Dirty()
end

function CMentoringTask:SetStepResultCnt(iPid, idx, iVal)
    table_set_depth(self.m_mStepResult, {iPid, idx}, "cnt", iVal)
    self:Dirty()
end

function CMentoringTask:GradeJudge(iGrade)
    return self.m_iApprenticeGrade >= iGrade
end

function CMentoringTask:PackTaskInfo(iPid)
    local lTask = {}
    for iTask, iCnt in pairs(self.m_mTask) do
        local mUnit = {}
        mUnit.task_id = iTask
        mUnit.task_cnt = iCnt
        table.insert(lTask, mUnit)
    end
    local lReward = {}
    for idx, iCnt in pairs(self.m_mReward[iPid] or {}) do
        local mUnit = {}
        mUnit.reward_id = idx
        mUnit.reward_cnt = iCnt
        table.insert(lReward, mUnit)
    end

    local lStepList = {}
    local mAllStep = self:GetAllStepResult()
    for idx, mStep in pairs(mAllStep) do
        local mUnit = {}
        mUnit.step_id = idx
        mUnit.status = table_get_depth(self.m_mStepResult, {iPid, idx, "status"})
        mUnit.step_cnt = table_get_depth(self.m_mStepResult, {iPid, idx, "cnt"})
        table.insert(lStepList, mUnit)
    end

    local mNet = {
        task_list = lTask,
        progress = self:GetProgress(),
        reward_list = lReward,
        key = self.m_sKey,
        step_list = lStepList,
    }

    return mNet
end

-----------评价---------------
function CMentoringTask:GetEvalutaion()
    return self.m_mEvalutaion
end

function CMentoringTask:SetEvalutaion(iKey, iVal)
    self.m_mEvalutaion[iKey] = iVal
    self:Dirty()
end

function CMentoringTask:GetEvalutaionScore()
    local iTotal, iCnt = 0, 0
    local mConfig = global.oMentoring:GetConfig()
    for _, iGrade in ipairs(mConfig.mentor_evalutaion) do
        if self.m_iApprenticeGrade >= iGrade and self.m_iStartGrade <= iGrade then
            iTotal = iTotal + (self.m_mEvalutaion[iGrade] or 75)
            iCnt = iCnt + 1
        end
    end
    return iCnt>0 and math.floor(iTotal/iCnt) or 0
end

function CMentoringTask:GetEvalutaionDesc(iScore)
    iScore = iScore or self:GetEvalutaionScore()
    for idx, mGrowup in ipairs(self:GetGrowupInfo()) do
        if iScore <= mGrowup.score then
            return mGrowup.desc, mGrowup.ratio
        end
    end
    return "", 0
end

function CMentoringTask:GetApprenticeForceTime()
    return self.m_iApprenticeForceTime
end

function CMentoringTask:SetApprenticeForceTime(iTime)
    self.m_iApprenticeForceTime = iTime
end

function CMentoringTask:GetMentorForceTime()
    return self.m_iMentorForceTime
end

function CMentoringTask:SetMentorForceTime(iTime)
    self.m_iMentorForceTime = iTime
end

function CMentoringTask:RefreshMentorTask(iPid)
    self:Validate()
    local iMentor, iApprentice = global.oMentoring:DecodeKey(self.m_sKey)
    local oMentor = global.oWorldMgr:GetOnlinePlayerByPid(iMentor)
    local oApprentice = global.oWorldMgr:GetOnlinePlayerByPid(iApprentice)
    if oMentor and iPid ~= iApprentice then
        if oApprentice then
            self:RefreshMentorTask2(iMentor, oApprentice)
        else
            global.oWorldMgr:LoadProfile(iApprentice, function(o)
                self:RefreshMentorTask2(iMentor, o)
            end)
        end
    end
    if oApprentice and iPid ~= iMentor then
        if oMentor then
            self:RefreshMentorTask2(iApprentice, oMentor)
        else
            global.oWorldMgr:LoadProfile(iMentor, function(o)
                self:RefreshMentorTask2(iApprentice, o)
            end)
        end
    end
end

function CMentoringTask:RefreshMentorTask2(iPid, oTarget)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mNet = self:PackTaskInfo(iPid)
    mNet.target_grade = oTarget:GetGrade()
    mNet.target_score = oTarget:GetScore()
    mNet.growup_num = table_count(oPlayer:Query("apprentice", {}))
    oPlayer:Send("GS2CMentoringTask", mNet)
end

function CMentoringTask:DoAllTaskReward(iPid)
    local iMentor, iApprentice = global.oMentoring:DecodeKey(self.m_sKey)
    local oMentor = global.oWorldMgr:GetOnlinePlayerByPid(iMentor)
    local oApprentice = global.oWorldMgr:GetOnlinePlayerByPid(iApprentice)
    if oMentor and iPid ~= iApprentice then
        --给mentor发奖励
        local mReward = self:GetRewardCnt(iMentor)
        local mAllReward = self:GetAllReward()
        for idx, mInfo in pairs(mAllReward) do
            if not mReward[idx] and self:GetProgress() >= mInfo.progress then
                self:AddRewardCnt(iMentor, idx, 1)
                global.oRewardMgr:RewardByGroup(oMentor, "mentoring", mInfo.reward_idx)
            end
        end
        
        local mAllStep = self:GetAllStepResult()
        local iPoint = 0
        for idx, mStep in pairs(mAllStep) do
            if global.oMentoring:ValidGetStepReward(oMentor, self, idx) == 1 then
                iPoint = iPoint + mStep.mentor_xiayi_point
                self:SetStepResultRewarded(iMentor, idx, 1)
            end
        end
        if iPoint > 0 then
            oMentor.m_oActiveCtrl:AddXiayiPoint(iPoint, "师傅出师领取所有奖励", {force=1})
            global.oMentoring:Notify(oMentor:GetPid(), 6006, {val=iPoint})
        end
        self:RefreshMentorTask(iMentor)
    end
    if oApprentice and iPid ~= iMentor then
        --给apprentice发奖励
        local mReward = self:GetRewardCnt(iApprentice)
        local mAllReward = self:GetAllReward()
        for idx, mInfo in pairs(mAllReward) do
            if not mReward[idx] and self:GetProgress() >= mInfo.progress then
                self:AddRewardCnt(iApprentice, idx, 1)
                global.oRewardMgr:RewardByGroup(oApprentice, "mentoring", mInfo.reward_idx)
            end
        end
        
        local mAllStep = self:GetAllStepResult()
        local iPoint = 0
        for idx, mStep in pairs(mAllStep) do
            if global.oMentoring:ValidGetStepReward(oApprentice, self, idx) == 1 then
                iPoint = iPoint + mStep.apprentice_xiayi_point
                self:SetStepResultRewarded(iApprentice, idx, 1)
            end
        end
        if iPoint > 0 then
            oApprentice.m_oActiveCtrl:AddXiayiPoint(iPoint, "徒弟出师领取所有奖励", {force=1})
            global.oMentoring:Notify(oApprentice:GetPid(), 6006, {val=iPoint})
        end
        self:RefreshMentorTask(iApprentice)
    end
end

function CMentoringTask:GetAllTask()
    return res["daobiao"]["mentoring"]["task"]
end

function CMentoringTask:GetAllReward()
    return res["daobiao"]["mentoring"]["progress_reward"]
end

function CMentoringTask:GetAllStepResult()
    return res["daobiao"]["mentoring"]["step_result"]
end

function CMentoringTask:GetGrowupInfo()
    return res["daobiao"]["mentoring"]["growup"]
end

