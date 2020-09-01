local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"
local statistics = require "public.statistics"
local router = require "base.router"

local gamedefines = import(lualib_path("public.gamedefines"))
local orgobj = import(service_path("org.orgobj"))
local orgready = import(service_path("org.orgready"))
local orgmeminfo = import(service_path("org.orgmeminfo"))
local analy = import(lualib_path("public.dataanaly"))
local orgdefines = import(service_path("org.orgdefines"))
local gamedb = import(lualib_path("public.gamedb"))

function NewOrgMgr(...)
    return COrgMgr:New(...)
end

COrgMgr = {}
COrgMgr.__index = COrgMgr
inherit(COrgMgr,logic_base_cls())

function COrgMgr:New()
    local o = super(COrgMgr).New(self)
    o.m_mNormalOrgs = {}
    o.m_mReadyOrgs = {}
    o.m_mNormalOrgNames = {}
    o.m_mReadyOrgNames = {}
    o.m_mOrgCreatingName = {}
    o.m_mOrgShowIds = {}
    o.m_mPlayerOrgMap = {}          -- 玩家帮派映射
    o.m_mPlayerApply = {}           -- 玩家申请的 {pid:{orgid:ture}}    

    o.m_mNormalOrgLoaded = false
    o.m_mReadyOrgLoaded = false
    o.m_mNormalOrgLoading = {}
    o.m_mReadyOrgLoading = {}

    o.m_lWaitLoadingFunc = {}

    -- o.m_mOrgListCache = {}
    o.m_mMulApplyTime = {}              --　一键申请时间记录　不存库
    o.m_mTestData = {}                  -- 临时测试数据
    return o
end

function COrgMgr:LoadAllOrg()
    local mInfo = {
        module = "orgdb",
        cmd = "GetAllOrgID",
    }
    gamedb.LoadDb("org", "common", "DbOperate", mInfo, function (mRecord, mData)
        if not is_release(self) then
            self:LoadAllNormalOrg(mRecord, mData)
        end
    end)
    local mInfo = {
        module = "orgreadydb",
        cmd = "GetAllReadyOrgID",
    }
    gamedb.LoadDb("org", "common", "DbOperate", mInfo, function (mRecord, mData)
        if not is_release(self) then
            self:LoadAllReadyOrg(mRecord, mData)
        end
    end)
end

function COrgMgr:LoadAllNormalOrg(mRecord, mData)
    local lData = mData.data
    if not lData or not next(lData) then
        self:OnAllNormalOrgLoaded()
        return
    end
    for _, v in ipairs(lData) do
        local orgid = v.orgid
        self.m_mNormalOrgLoading[orgid] = true
        self:LoadNormalOrg(orgid)
    end
end

function COrgMgr:LoadAllReadyOrg(mRecord, mData)
    local lData = mData.data
    if not lData or not next(lData) then
        self:OnAllReadyOrgLoaded()
        return
    end
    for _, v in ipairs(lData) do
        local orgid = v.orgid
        self.m_mReadyOrgLoading[orgid] = true
        self:LoadReadyOrg(orgid)
    end
end

function COrgMgr:LoadNormalOrg(orgid)
    local mInfo = {
        module = "orgdb",
        cmd = "LoadWholeOrg",
        cond = {orgid = orgid},
    }
    gamedb.LoadDb(orgid, "common", "DbOperate", mInfo, function (mRecord, mData)
        if not is_release(self) then
            self:LoadNormalOrg2(mRecord, mData)
        end
    end)
end

function COrgMgr:LoadNormalOrg2(mRecord, mData)
    local orgid = mData.orgid
    if not self.m_mNormalOrgLoading[orgid] then
        return
    end
    local oOrg = orgobj.NewOrg(orgid)
    oOrg:LoadAll(mData.data)
    if oOrg:GetMemberCnt() <= 0 and oOrg:GetXueTuCnt() <= 0 then
        baseobj_delay_release(oOrg)
    else
        oOrg:OnLoaded()
        oOrg:Schedule()
        self:AddNormalOrg(oOrg)
        oOrg:CheckMaintain()        
    end
    self.m_mNormalOrgLoading[orgid] = nil
    if not next(self.m_mNormalOrgLoading) then
        self:OnAllNormalOrgLoaded()
    end
end

function COrgMgr:LoadReadyOrg(orgid)
    local mInfo = {
        module = "orgreadydb",
        cmd = "LoadReadyOrg",
        cond = {orgid = orgid},
    }
    gamedb.LoadDb(orgid, "common", "DbOperate", mInfo, function (mRecord, mData)
        if not is_release(self) then
            self:LoadReadyOrg2(mRecord, mData)
        end
    end)
end

function COrgMgr:LoadReadyOrg2(mRecord, mData)
    local orgid = mData.orgid
    if not self.m_mReadyOrgLoading[orgid] then
        return
    end
    local oOrg = orgready.NewReadyOrg(orgid)
    oOrg:Load(mData.data)
    oOrg:OnLoaded()
    self:AddReadyOrg(oOrg)
    self.m_mReadyOrgLoading[orgid] = nil
    if not next(self.m_mReadyOrgLoading) then
        self:OnAllReadyOrgLoaded()
    end
end

function COrgMgr:OnAllNormalOrgLoaded()
    self.m_mNormalOrgLoaded = true
    self:OnAllOrgLoaded()
end

function COrgMgr:OnAllReadyOrgLoaded()
    self.m_mReadyOrgLoaded = true
    self:OnAllOrgLoaded()
end

function COrgMgr:OnAllOrgLoaded()
    if not self.m_mNormalOrgLoaded or not self.m_mReadyOrgLoaded then
        return
    end
    self:WakeUpFunc()
    self:Schedule()
    self:CreateOrgListVersion()
end

function COrgMgr:Execute(func)
    if self.m_mNormalOrgLoaded and self.m_mReadyOrgLoaded then
        func()
    else
        table.insert(self.m_lWaitLoadingFunc,func)
    end
end

function COrgMgr:WakeUpFunc()
    local lWaitFuncs = self.m_lWaitLoadingFunc
    self.m_lWaitLoadingFunc = {}
    for _,func in pairs(lWaitFuncs) do
        func()
    end
end

function COrgMgr:Schedule()
    -- local f1
    -- f1 = function ()
    --     self:DelTimeCb("GenerateCache")
    --     self:AddTimeCb("GenerateCache", 5 * 60 * 1000, f1)
    --     self:GenerateCache()
    -- end
    -- f1()
end

function COrgMgr:NewHour(mNow)
    local iHour = mNow.date.hour
    for orgid, oOrg in pairs(self.m_mNormalOrgs) do
        safe_call(oOrg.NewHour, oOrg, mNow)
    end

    if iHour == 3 then
        self:PushOrgStatistics()
    end 
    local oVersionMgr = global.oVersionMgr
    oVersionMgr:CommitVersion(oVersionMgr:GetOrgListType())    
end

function COrgMgr:PushOrgStatistics()
    local mRecord, mOrg = {}, {}
    for _, oOrg in pairs(self.m_mNormalOrgs) do
        local sLevel = db_key(oOrg:GetLevel())
        mOrg[sLevel] = (mOrg[sLevel] or 0) + 1 

        local mData = mRecord[sLevel]
        if not mData then
            mData = {}
            mRecord[sLevel] = mData
        end

        for _, oMem in pairs(oOrg.m_oMemberMgr:GetMemberMap()) do
            local sGrade = db_key((oMem:GetGrade() // 10) * 10)
            mData[sGrade] = (mData[sGrade] or 0) + 1
        end

        for _, oMem in pairs(oOrg.m_oMemberMgr:GetXueTuMap()) do
            local sGrade = db_key((oMem:GetGrade() // 10) * 10)
            mData[sGrade] = (mData[sGrade] or 0) + 1
        end
    end

    statistics.record_org_member(mRecord, mOrg)
end

function COrgMgr:HasSameName(sName)
    if self:GetReadyOrgByName(sName) then return true end

    if self:GetNormalOrgByName(sName) then return true end

    if self.m_mOrgCreatingName[sName] then return true end

    return false
end

----------------------old create org---------------------------
-- function COrgMgr:CreateReadyOrg(oPlayer, sName, sAim, isGm)
--     local oNotifyMgr = global.oNotifyMgr
--     if self:HasSameName(sName) then
--         oNotifyMgr:Notify(oPlayer:GetPid(), self:GetOrgText(1068))
--         return
--     end
--     if oPlayer:GetOrgStatus() > 0 then return end

--     if not isGm then
--         local res = require "base.res"
--         local iVal = res["daobiao"]["org"]["others"][1]["create_yuanbao"]
--         local oProfile = oPlayer:GetProfile()
--         if oProfile:TrueGoldCoin() < iVal then
--             oPlayer:NotifyMessage(self:GetOrgText(1179))
--             return
--         end
--         oProfile:ResumeTrueGoldCoin(iVal, "创建帮派")
--     end

--     local mLog = oPlayer:LogData()
--     mLog["org_name"] = sName
--     record.log_db("org", "create_ready_org", mLog)

--     self.m_mOrgCreatingName[sName] = true
--     self:CreateReadyOrg2(oPlayer:GetPid(), sName, sAim) 
-- end

-- function COrgMgr:CreateReadyOrg2(iPid, sName, sAim)
--     router.Request("cs", ".idsupply", "common", "GenOrgId", {}, function (mRecord, mData)
--         local iOrgId = mData.id
--         if not iOrgId then
--             record.error("create org error GenOrgId nil")
--             return
--         end
--         self:CreateReadyOrg3(iOrgId, iPid, sName, sAim)
--     end)
-- end

-- function COrgMgr:CreateReadyOrg3(orgid, pid, sName, sAim)
--     self.m_mOrgCreatingName[sName] = nil

--     local iShowId = global.oWorldMgr:DispatchOrgShowId()
--     local oWorldMgr = global.oWorldMgr
--     local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
--     assert(oPlayer, string.format("create org no owner exist %d", pid))
--     if oPlayer:GetOrgStatus() > 0 then return end

--     self:OnJoinDelResponds(pid)
--     local oOrg = orgready.NewReadyOrg(orgid)
--     oOrg:Create(oPlayer, iShowId, sName, sAim)
--     local mData = oOrg:Save()
--     mData["orgid"] = orgid

--     local mInfo = {
--         module = "orgreadydb",
--         cmd = "CreateReadyOrg",
--         data = {data = mData},
--     }
--     gamedb.SaveDb(orgid, "common", "DbOperate", mInfo)
--     oOrg:OnLoaded()
--     self:AddReadyOrg(oOrg)

--     local sMsg = string.format("%s {link10, %d, %d}", self:GetOrgText(1020), oOrg:OrgID(), oPlayer:GetPid())
--     local oChatMgr = global.oChatMgr
--     oChatMgr:SendMsg2World(sMsg, oPlayer)
--     oPlayer:Send("GS2CCreateOrg",{})
--     oPlayer:PropChange("org_status", "org_id")
--     oPlayer:NotifyMessage(self:GetOrgText(1019))
-- end

function COrgMgr:CreateNormalOrg_old(oReadyOrg)
    local orgid = oReadyOrg:OrgID()

    local mLog = {}
    mLog["org_id"] = orgid
    mLog["org_name"] = oReadyOrg:GetName()
    mLog["leader"] = oReadyOrg:GetLeader()
    record.log_db("org", "create_normal_org", mLog)

    local oOrg = orgobj.NewOrg(orgid)
    oOrg:Create(oReadyOrg:GetName(), oReadyOrg:ShowID(), oReadyOrg:GetAim())
    local mInfo = {
        module = "orgdb",
        cmd = "CreateOrg",
        data = {data = oOrg:GetAllSaveData()},
    }
    gamedb.SaveDb(orgid, "common", "DbOperate", mInfo)
    oOrg:OnLoaded()
    oOrg:Schedule()
    self:AddNormalOrg(oOrg)

    for pid, meminfo in pairs(oReadyOrg.m_mRespondInfo) do
        oOrg:AddMember(meminfo)
        if self:GetPlayerOrgId(pid) and self:GetPlayerOrgId(pid) > 0 then
            goto continue
        end
        -- if pid ~= oReadyOrg:GetLeader() then
        --     oOrg:CheckPositionTitle(pid)
        -- end
        self:OnJoinOrg(pid, orgid, pid == oReadyOrg:GetLeader())
        ::continue::
    end

    local iLeader = oReadyOrg:GetLeader()
    oOrg:SetLeader(iLeader)
    -- oOrg:CheckPositionTitle(oReadyOrg:GetLeader())
    oOrg:Setup()
    oOrg:CreateOrgScene()
    oOrg:CreateOrgMemberVersion()
    self:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.ADD, orgid, oOrg:PackOrgListInfo())

    self:SendMail4CreateSuccess(iLeader, oOrg:GetName())
    -- self:GenerateCache()
    if oReadyOrg:GetData("renamecard", 0) > 0 then
        local oMailMgr = global.oMailMgr
        local oItem = global.oItemLoader:ExtCreate(10179)
        local mData, name = oMailMgr:GetMailInfo(9002)
        oMailMgr:SendMail(0, name, iLeader, mData, 0, {oItem})
    end

    self:DeleteReadyOrg(oReadyOrg)
    self:TriggerEvent(gamedefines.EVENT.CREATE_ORG, {org = oOrg})

    local sMsg = self:GetOrgText(1159, {role=oOrg:GetLeaderName()})
    oOrg:AddLog(0, sMsg)
    return oOrg
end
----------------------old create org end---------------------------

function COrgMgr:GetCreateGoldCoin()
    local res = require "base.res"
    return res["daobiao"]["org"]["others"][1]["create_yuanbao"] 
end

----------------------new create org---------------------------
function COrgMgr:CreateNormalOrg(oPlayer, sName, sAim, bGmCreate)
    local iOrg = oPlayer:GetOrgID()
    if iOrg and iOrg ~= 0 then return end

    if self:HasSameName(sName) then
        oPlayer:NotifyMessage(self:GetOrgText(1068))
        return
    end

    if not bGmCreate then
        local iGoldCoin = self:GetCreateGoldCoin()
        local oProfile = oPlayer:GetProfile()
        if oProfile:TrueGoldCoin() < iGoldCoin then
            oPlayer:NotifyMessage(self:GetOrgText(1179))
            return
        end
        oProfile:ResumeTrueGoldCoin(iGoldCoin, "创建帮派")
    end
    self.m_mOrgCreatingName[sName] = true
    self:CreateNormalOrg2(oPlayer:GetPid(), sName, sAim) 
end

function COrgMgr:CreateNormalOrg2(iPid, sName, sAim)
    router.Request("cs", ".idsupply", "common", "GenOrgId", {}, function (mRecord, mData)
        local iOrgId = mData.id
        if not iOrgId then
            record.error("create org error GenOrgId nil")
            return
        end
        self:CreateNormalOrg3(iOrgId, iPid, sName, sAim)
    end)
end

function COrgMgr:CreateNormalOrg3(iOrgId, iPid, sName, sAim)
    self.m_mOrgCreatingName[sName] = nil

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    assert(oPlayer, string.format("create org no owner exist %d", iPid))
    local iCurOrg = oPlayer:GetOrgID()
    if iCurOrg and iCurOrg ~= 0 then return end

    record.log_db("org", "create_normal_org", {
        org_id = iOrgId,
        org_name = sName,
        leader = iPid,
    })

    local oOrg = orgobj.NewOrg(iOrgId)
    local iShowId = oWorldMgr:DispatchOrgShowId()
    oOrg:Create(sName, iShowId, sAim)
    local mInfo = {
        module = "orgdb",
        cmd = "CreateOrg",
        data = {data = oOrg:GetAllSaveData()},
    }
    gamedb.SaveDb(iOrgId, "common", "DbOperate", mInfo)
    oOrg:OnLoaded()
    oOrg:Schedule()
    self:AddNormalOrg(oOrg)

    local oMember = self:CreateMemberInfo(oPlayer)
    oOrg:AddMember(oMember)
    baseobj_delay_release(oMember)
    self:OnJoinOrg(iPid, iOrgId, true)
    oOrg:SetLeader(iPid)
    oOrg:Setup()
    -- oOrg:CreateOrgScene()
    oOrg:CreateOrgMemberVersion()
    self:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.ADD, iOrgId, oOrg:PackOrgListInfo())
    self:SendMail4CreateSuccess(iPid, sName)
    self:TriggerEvent(gamedefines.EVENT.CREATE_ORG, {org = oOrg})

    local sMsg = self:GetOrgText(1159, {role=oPlayer:GetName()})
    oOrg:AddLog(0, sMsg)
    return oOrg
end
----------------------new create org end---------------------------

function COrgMgr:CreateMemberInfo(oPlayer)
    local mArgs = {
        pid = oPlayer:GetPid(),
        name = oPlayer:GetName(),
        grade = oPlayer:GetGrade(),
        school = oPlayer:GetSchool(),
        offer = oPlayer:GetOffer(),
        touxian = oPlayer.m_oTouxianCtrl:GetTouxianID()
    }
    local oMember = orgmeminfo.NewMemberInfo()
    oMember:CreateNew(mArgs)
    return oMember
end

function COrgMgr:AddReadyOrg(oOrg)
    local id = oOrg:OrgID()
    local name = oOrg:GetName()
    self.m_mReadyOrgs[id] = oOrg
    self.m_mReadyOrgNames[name] = true
    self.m_mOrgShowIds[oOrg:ShowID()] = id
end

function COrgMgr:AddNormalOrg(oOrg)
    local id = oOrg:OrgID()
    local name = oOrg:GetName()
    self.m_mNormalOrgs[id] = oOrg
    self.m_mNormalOrgNames[name] = true
    self.m_mOrgShowIds[oOrg:ShowID()] = id

    -- self:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.ADD, id, oOrg:PackOrgListInfo())
end

function COrgMgr:DeleteReadyOrg(oOrg)
    local id = oOrg:OrgID()
    local name = oOrg:GetName()
    local mInfo = {
        module = "orgreadydb",
        cmd = "RemoveReadyOrg",
        cond = {orgid = id},
    }
    gamedb.SaveDb(id, "common", "DbOperate", mInfo)
    self.m_mReadyOrgs[id] = nil
    self.m_mReadyOrgNames[name] = nil
    self.m_mOrgShowIds[oOrg:ShowID()] = nil
    baseobj_delay_release(oOrg)
end

function COrgMgr:DeleteNormalOrg(oOrg)
    local id = oOrg:OrgID()
    local name = oOrg:GetName()
    local mInfo = {
        module = "orgdb",
        cmd = "RemoveOrg",
        cond = {orgid = id},
    }
    gamedb.SaveDb(id, "common", "DbOperate", mInfo)
    baseobj_delay_release(oOrg)
    oOrg:RemoveOrgScene()
    
    self.m_mNormalOrgs[id] = nil
    self.m_mNormalOrgNames[name] = nil
    self.m_mOrgShowIds[oOrg:ShowID()] = nil
    global.oRankMgr:PushDataToOrgPrestige(oOrg, true)

    local oRedPacketMgr=global.oRedPacketMgr
    oRedPacketMgr:DeleteOrgRP(id)
    self:PushOrgListToVersion(gamedefines.VERSION_OP_TYPE.DELETE, id, {})
    
    local oVersionMgr = global.oVersionMgr
    oVersionMgr:DeleteVersion(oVersionMgr:GetOrgMemberType(id))
end

function COrgMgr:DismissNormalOrg(iOrgID)
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg then return end

    oOrg:SendMail4DismissOrg()
    local mLog = oOrg:LogData()
    record.log_db("org", "dismiss_org", mLog)

    -- 先学徒　,成员
    for iPid, oXueTu in pairs(oOrg.m_oMemberMgr:GetXueTuMap()) do
        safe_call(self.LogAnalyInfo, self, iPid, iOrgID, 4)
        self:LeaveOrg(iPid, iOrgID, "帮派解散")
    end

    for iPid, oMem in pairs(oOrg.m_oMemberMgr:GetMemberMap()) do
        safe_call(self.LogAnalyInfo, self, iPid, iOrgID, 4)
        self:LeaveOrg(iPid, iOrgID, "帮派解散")
    end
    -- self:DeleteNormalOrg(oOrg)
end

function COrgMgr:GetReadyOrg(id)
    return self.m_mReadyOrgs[id]
end

function COrgMgr:GetReadyOrgByPid(iPid)
    for _,oOrg in pairs(self.m_mReadyOrgs) do
        if oOrg:GetLeader() == iPid then
            return oOrg
        end
    end
    return nil
end

function COrgMgr:GetOrgIdByShowId(iShowId)
    return self.m_mOrgShowIds[iShowId]
end

function COrgMgr:GetNormalOrgs()
    return self.m_mNormalOrgs
end

function COrgMgr:GetNormalOrg(id)
    return self.m_mNormalOrgs[id]
end

function COrgMgr:GetReadyOrgByName(sName)
    return self.m_mReadyOrgNames[sName]
end

function COrgMgr:GetNormalOrgByName(sName)
    return self.m_mNormalOrgNames[sName]
end

function COrgMgr:GetReadyOrgs()
    return self.m_mReadyOrgs
end

function COrgMgr:AddPlayerApply(iPid, iOrg)
    local mOrgId = self.m_mPlayerApply[iPid]
    if not mOrgId then
        mOrgId = {}
        self.m_mPlayerApply[iPid] = mOrgId
    end
    mOrgId[iOrg] = true
end

function COrgMgr:RemovePlayerApply(iPid, iOrg)
    local mOrgId = self.m_mPlayerApply[iPid]
    if mOrgId then
        mOrgId[iOrg] = nil
    end
end

function COrgMgr:GetApplyOrgList(iPid)
    local mOrgId = self.m_mPlayerApply[iPid]
    if not mOrgId then return end

    return table_key_list(mOrgId)
end

function COrgMgr:SetPlayerOrgId(iPid, iOrgID)
    self.m_mPlayerOrgMap[iPid] = iOrgID
end

function COrgMgr:GetPlayerOrgId(iPid)
    return self.m_mPlayerOrgMap[iPid]
end

function COrgMgr:AcceptMember(orgid, pid)
    local oOrg = self:GetNormalOrg(orgid)
    if not oOrg then return end

    local oMem = oOrg:GetApplyInfo(pid)
    if not oMem then return end

    local flag = oOrg:AcceptMember(oMem)
    if flag then
        self:OnJoinOrg(pid, orgid)
    end
    return flag
end

function COrgMgr:AddForceMember(orgid, oPlayer)
    local oOrg = self:GetNormalOrg(orgid)
    if not oOrg then return end

    local iPid = oPlayer:GetPid()
    local oMember = self:CreateMemberInfo(oPlayer)
    -- oMember:CreateNew(mArgs)
    -- oMember:Create(pid, name, grade, school, offer)
    local flag = oOrg:AcceptMember(oMember)
    baseobj_delay_release(oMember)
    if flag then
        self:OnJoinOrg(iPid, orgid)
    end
    return flag
end

function COrgMgr:OnJoinOrg(pid, iOrgID, bLeader)
    local oOrg = self:GetNormalOrg(iOrgID)
    local mLog = oOrg:LogData()
    mLog["pid"] = pid
    record.log_db("org", "join_org", mLog)
    safe_call(self.LogAnalyInfo, self, pid, iOrgID, 1)

    self:OnJoinDelResponds(pid, iOrgID)
    self:OnJoinDelApplys(pid, iOrgID)
    self:SetPlayerOrgId(pid, iOrgID)
    oOrg:PushOrgMember2Version(pid, gamedefines.VERSION_OP_TYPE.ADD)

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:OnOrgChannel(iOrgID, oPlayer)
        oPlayer:PropChange("org_status", "org_id", "orgname", "org_pos")
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            local oMem = oTeam:GetMember(pid)
            if oMem then
                oMem:Update({orgid=iOrgID})
            end
        end
        oOrg:GS2COrgFlagInfo(oPlayer)
        oPlayer:RefreshCulSkillUpperLevel()
    end

    local oMemInfo = oOrg:GetMemberFromAll(pid)
    local sMsg = self:GetOrgText(1158, {role=oMemInfo:GetName()})
    oOrg:AddLog(0, sMsg)
    oOrg:SavePlayerMerge(pid)

    if not bLeader then
        oOrg:CheckPositionTitle(pid)
    end
    self:SendMail4JoinOrg(pid, iOrgID, bLeader)
    self:SendWelcomeMsg2Org(iOrgID, oMemInfo:GetName())
    self:TriggerEvent(gamedefines.EVENT.JOIN_ORG, {pid = pid, org = oOrg})

    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHuodong then
        oHuodong:OnOrgCnt(oOrg,pid)
    end

end

function COrgMgr:OnJoinDelResponds(pid, iOrgID)
    for orgid, oReadyOrg in pairs(self.m_mReadyOrgs) do
        if iOrgID ~= orgid then
            oReadyOrg:DelRespond(pid)
        end
    end
end

function COrgMgr:OnJoinDelApplys(pid, iOrgID)
    for orgid, oOrg in pairs(self.m_mNormalOrgs) do
        if iOrgID ~= orgid then
            oOrg:RemoveApply(pid)
        end
    end
end

function COrgMgr:SaveMerge(oOrg, iPid)
    if not oOrg then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oOrg:AddSaveMerge(oPlayer)
    else
        local oProfile = global.oWorldMgr:GetProfile(iPid)
        if oProfile then
            oOrg:AddSaveMerge(oProfile)    
        end
    end
end

function COrgMgr:LeaveOrg(pid, iOrgID, sReason)
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg then return end

    local mLog = oOrg:LogData()
    mLog["pid"] = pid
    mLog["reason"] = sReason
    record.log_db("org", "leave_org", mLog)

    oOrg:ClearOrgTitle(pid)
    if pid == oOrg:GetApplyLeader() then
        oOrg:RemoveApplyLeader()
        oOrg:GS2COrgApplyFlag()
    end
    oOrg:RemoveMember(pid)
    self:SetPlayerOrgId(pid, nil)
    oOrg:PushOrgMember2Version(pid, gamedefines.VERSION_OP_TYPE.DELETE)

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        self:OffOrgChannel(iOrgID, oPlayer)
        oPlayer:PropChange("org_status", "org_id", "orgname")
        oOrg:GS2COrgInitFlagInfo(oPlayer)
        oPlayer:RefreshCulSkillUpperLevel()
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            local oMem = oTeam:GetMember(pid)
            if oMem then
                oMem:Update({orgid=0})
            end
        end
    end
    oOrg:SavePlayerMerge(pid)
    self:TriggerEvent(gamedefines.EVENT.LEAVE_ORG, {org = oOrg, pid = pid})

    if oOrg:GetMemberCnt() <= 0 then
        self:DeleteNormalOrg(oOrg)
    end
    global.oTitleMgr:OnLeaveOrg(pid)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if oHuodong then
        oHuodong:OnLeaveOrg(pid)
    end
end

function COrgMgr:OnCreateOrgFail(orgid)
    local oReadyOrg = self:GetReadyOrg(orgid)
    if oReadyOrg then
        local iPid = oReadyOrg:GetLeader()
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        self:SendMail4CreateFail(iPid, oReadyOrg:GetCreateTime())
        self:DeleteReadyOrg(oReadyOrg)
        if oPlayer then
            oPlayer:PropChange("org_status", "org_id")
        end
    end
end

function COrgMgr:RenameOrg(iOrgID, sNewName)
    if self:HasSameName(sNewName) then
        return false
    end
    self:ForceRenameOrg(iOrgID, sNewName)
end

function COrgMgr:ForceRenameOrg(iOrgID, sNewName)
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg then return false end

    local oOldName = oOrg:GetName()
    oOrg:SetData("name", sNewName)
    self:OnOrgChangeName(iOrgID, oOldName, sNewName)
    oOrg:OnChangeName()
    self:RefreshDbName(iOrgID, sOldName, sNewName)
end

function COrgMgr:ForceRenameReadyOrg(iOrgId, sNewName)
    local oOrg = self:GetReadyOrg(iOrgId)
    if not oOrg then return false end
    local oOldName = oOrg:GetName()
    oOrg:SetData("name", sNewName)
    self:OnOrgChangeName(iOrgID, oOldName, sNewName)
    self:RefreshDbName(iOrgID, sOldName, sNewName)
end

function COrgMgr:OnOrgChangeName(iOrgID, sOldName, sNewName)
    local oOrg = self:GetNormalOrg(iOrgID)
    if oOrg then
        self.m_mNormalOrgNames[sOldName] = nil
        self.m_mNormalOrgNames[sNewName] = true
    else
        oOrg = self:GetReadyOrg(iOrgID)
        if oOrg then
            self.m_mReadyOrgNames[sOldName] = nil
            self.m_mReadyOrgNames[sNewName] = true
        end
    end
end

function COrgMgr:RefreshDbName(iOrgId, sOldName, sNewName)
    local oRankMgr = global.oRankMgr
    oRankMgr:OnUpdateOrgName(iOrgId, sNewName)
end

-- function COrgMgr:GenerateCache()
--     local mNormalOrgs = {}
--     local iCount = 0
--     local lOrgIDs = table_key_list(self.m_mNormalOrgs)
--     table.sort(lOrgIDs)
--     for _, orgid in pairs(lOrgIDs) do
--         local oOrg = self.m_mNormalOrgs[orgid]
--         if oOrg:GetMember(oOrg:GetLeaderID()) then
--             table.insert(mNormalOrgs, oOrg:PackOrgListInfo())
--             iCount = iCount + 1
--             if iCount >= 200 then
--                 break
--             end
--         end
--     end
--     self.m_mOrgListCache = mNormalOrgs
-- end

-- function COrgMgr:UpdateCacheInfo(oOrg, iPid)
--     for _, mOrg in ipairs(self.m_mOrgListCache) do
--         if mOrg.orgid == oOrg:OrgID() and mOrg.leaderid == iPid then
--             mOrg.leadername = oOrg:GetLeaderName()
--         end
--     end
-- end

-- function COrgMgr:GetOrgListCache()
--     return self.m_mOrgListCache
-- end

function COrgMgr:GetMultiApplyOrgList(oPlayer)
    local lOrgSort, iText = {}, 1165
    for iOrg, oOrg in pairs(self.m_mNormalOrgs) do
        if not oOrg:GetLeader() or oOrg:IsFull(true) then
            goto continue
        end
        iText = 1045
        oOrg:CheckOrgApply()
        if oOrg:GetApplyCnt() >= orgdefines.APPLY_MAX_NUM then
            goto continue
        end
        table.insert(lOrgSort, {iOrg, oOrg:GetLastWeekHuoYue(), oOrg:IsMultiApply(oPlayer)})    
        ::continue::
    end
    if #lOrgSort <= 0 then
        return lOrgSort, iText
    end
    if #lOrgSort <= orgdefines.MULTI_APPLY_NUM then
        local lRet = {}
        for _, m in pairs(lOrgSort) do
            table.insert(lRet, m[1])
        end
        return lRet
    end

    table.sort(lOrgSort, function(v1, v2)
        if v1[2] == v2[2] then
            if v1[1] == v2[1] then return false end

            return v1[1] > v2[1]
        else
            return v1[2] > v2[2]
        end
    end)

    local lOrgIDs1, lOrgIDs2 = {}, {}
    for i = 1, math.min(50, #lOrgSort) do
        local iOrg, _, bMulti = table.unpack(lOrgSort[i])
        if bMulti then
            table.insert(lOrgIDs1, iOrg)
        else
            table.insert(lOrgIDs2, iOrg)
        end         
    end

    local lOrgIDs = {}
    if #lOrgIDs1 >= orgdefines.MULTI_APPLY_NUM then
        lOrgIDs = extend.Random.random_size(lOrgIDs1, orgdefines.MULTI_APPLY_NUM)
    else
        lOrgIDs2 = extend.Random.random_size(lOrgIDs2, orgdefines.MULTI_APPLY_NUM - #lOrgIDs1)
        lOrgIDs = list_combine(lOrgIDs1, lOrgIDs2)
    end
    return lOrgIDs
end

function COrgMgr:MultiApplyJoinOrg(oPlayer)
    if table_count(self.m_mNormalOrgs) <= 0 then return end

    local lOrgIDs, iText = self:GetMultiApplyOrgList(oPlayer)
    if #lOrgIDs <= 0 then
        return {}, iText
    end
    local mNet = {}
    for _,iOrg in pairs(lOrgIDs) do
        local oOrg = self:GetNormalOrg(iOrg)
        if oOrg then
            if oPlayer:GetOrg() then break end

            oOrg:AddApply(oPlayer, orgdefines.ORG_APPLY.APPLY)
            table.insert(mNet, iOrg)
        end
    end
    return mNet
end

function COrgMgr:SendMail4CreateFail(iPid, createtime)
    local oMailMgr = global.oMailMgr
    local oNotifyMgr = global.oNotifyMgr
    local mData, name = oMailMgr:GetMailInfo(3007)
    if not mData then
        return
    end
    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {bpcjtime=get_time_format_str(get_time(), "%Y-%m-%d日%H时")})
    oMailMgr:SendMail(0, name, iPid, mInfo, 0)
end

function COrgMgr:SendMail4CreateSuccess(iPid, orgName)
    local oMailMgr = global.oMailMgr
    local oNotifyMgr = global.oNotifyMgr
    local mData, name = oMailMgr:GetMailInfo(3008)
    if not mData then
        return
    end
    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {bpname=orgName})
    oMailMgr:SendMail(0, name, iPid, mInfo, 0)
end

function COrgMgr:SendMail4JoinOrg(iPid, iOrgID, bLeader)
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg or bLeader then return end

    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(3009)
    if oOrg:IsXueTu(iPid) then
        mData, name = oMailMgr:GetMailInfo(3020)
    end
    if not mData then return end 
        
    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    local orgName = oOrg:GetName()
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {bpname=orgName})
    mInfo.context = string.format(mInfo.context, iOrgID)
    oMailMgr:SendMail(0, name, iPid, mInfo, 0)
end

function COrgMgr:SendMail2Player(iPid, iMail, mReplace)
    local oMailMgr = global.oMailMgr
    local mData, name = oMailMgr:GetMailInfo(iMail)
    if not mData then return end
        
    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    if mReplace then
        mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    end
    oMailMgr:SendMail(0, name, iPid, mInfo, 0)
end

function COrgMgr:GetMaxRespondCnt()
    local res = require "base.res"
    local iCnt = res["daobiao"]["org"]["others"][1]["create_respond_people"]
    return iCnt
end

-- 这个方法只是同步玩家响应信息与申请信息
function COrgMgr:SyncPlayerData(iPid, mData)
    for _,oReadyOrg in pairs(self.m_mReadyOrgs) do
        oReadyOrg:SyncRespondData(iPid, mData)
    end
    for _,oOrg in pairs(self.m_mNormalOrgs) do
        oOrg:SyncApplyData(iPid, mData)
    end
end

function COrgMgr:SetMulApplyTime(iPid)
    self.m_mMulApplyTime[iPid] = get_time()
end

function COrgMgr:GetMulApplyLeftTime(iPid)
    local res = require "base.res"
    local iLefeTime = self.m_mMulApplyTime[iPid] or 0
    local iTime = res["daobiao"]["org"]["others"][1]["multi_apply_org"]
    return math.max(iLefeTime + iTime - get_time(), 0)
end

function COrgMgr:OnDisconnected(oPlayer)
    if not oPlayer:GetProfile() then return end

    if not oPlayer:GetOrg() then
        return
    end
    local iOrgID = oPlayer:GetOrgID()
    -- oPlayer:SyncLogoutTime2Org()
    self:OffOrgChannel(iOrgID, oPlayer)
end

function COrgMgr:OnLogout(oPlayer)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then
        return
    end
    local iOrgID = oPlayer:GetOrgID()
    oPlayer:SyncLogoutTime2Org()
    self:OffOrgChannel(iOrgID, oPlayer)
    -- oOrg:PushOrgMember2Version(oPlayer:GetPid(), gamedefines.VERSION_OP_TYPE.UPDATE)
end

function COrgMgr:OnLogin(oPlayer, bReEnter)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    local iOrgID = oPlayer:GetOrgID()
    oOrg:GS2COrgFlagInfo(oPlayer)
    self:OnOrgChannel(iOrgID, oPlayer)

    --　称谓
    oOrg:CheckPositionTitle(oPlayer:GetPid())
    oOrg:CheckEliteTitle(oPlayer)
    oOrg:PushOrgMember2Version(oPlayer:GetPid(), gamedefines.VERSION_OP_TYPE.UPDATE)
end

function COrgMgr:OnOrgChannel(iOrgID, oPlayer)
    local mBroadcastRole = {
        pid = oPlayer:GetPid(),
    }
    local gamedefines = import(lualib_path("public.gamedefines"))
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.ORG_TYPE, iOrgID, true},
        },
        info = mBroadcastRole,
    })
end

function COrgMgr:OffOrgChannel(iOrgID, oPlayer)
    local mBroadcastRole = {
        pid = oPlayer:GetPid(),
    }
    local gamedefines = import(lualib_path("public.gamedefines"))
    interactive.Send(".broadcast", "channel", "SetupChannel", {
        pid = oPlayer:GetPid(),
        channel_list = {
            {gamedefines.BROADCAST_TYPE.ORG_TYPE, iOrgID, false},
        },
        info = mBroadcastRole,
    })
end

function COrgMgr:GetOrgText(iText, m)
    local oToolMgr = global.oToolMgr
    local sText = oToolMgr:GetTextData(iText, {"org"})
    if sText and m then
        sText = oToolMgr:FormatColorString(sText, m)
    end
    return sText
end

function COrgMgr:SendWelcomeMsg2Org(iOrgID, sName)
    local oToolMgr = global.oToolMgr
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg then
        return
    end
    local sMsg = oToolMgr:FormatColorString(self:GetOrgText(1062), {role=sName})
    self:SendMsg2Org(iOrgID, sMsg)
end

function COrgMgr:SendMsg2Org(iOrgID, sMsg, oPlayer)
    local oChatMgr = global.oChatMgr
    oChatMgr:SendMsg2Org(sMsg, iOrgID, oPlayer)
end

function COrgMgr:SendMail4BeKicked(iPid, sOrgName)
    local oMailMgr = global.oMailMgr
    local oNotifyMgr = global.oNotifyMgr
    local mData, name = oMailMgr:GetMailInfo(3010)
    if not mData then
        return
    end
    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {bpname=sOrgName})
    oMailMgr:SendMail(0, name, iPid, mInfo, 0)
end

function COrgMgr:GetOrgOnlineMembers(iOrgId)
    local oOrg = self:GetNormalOrg(iOrgId)
    if not oOrg then
        return {}
    end
    return oOrg:GetOnlineMembers()
end

function COrgMgr:CreateOrgListVersion()
    local mData = {}
    for iOrg, oOrg in pairs(self.m_mNormalOrgs) do
        if oOrg:GetLeader() then
            mData[iOrg] = oOrg:PackOrgListInfo() 
        end
    end
    local oVersionMgr = global.oVersionMgr
    oVersionMgr:CreateVersionObj(oVersionMgr:GetOrgListType(), "orglist", mData)
end

function COrgMgr:PushOrgListToVersion(iOpType, iOrg, mInfo)
    local oVersionMgr = global.oVersionMgr
    oVersionMgr:PushDataToVersion(oVersionMgr:GetOrgListType(), iOpType, iOrg, mInfo)
end

function COrgMgr:LogAnalyInfo(iPid, iOrgID, iOperation)
    local oOrg = self:GetNormalOrg(iOrgID)
    if not oOrg then return end

    local mAnalyLog = {}
    mAnalyLog["operation"] = iOperation
    mAnalyLog["faction_id"] = iOrgID
    mAnalyLog["faction_name"] = oOrg:GetName()
    mAnalyLog["faction_level"] = oOrg:GetLevel()
    mAnalyLog["faction_pro"] = oOrg:GetPosition(iPid)
    mAnalyLog["faction_num"] = oOrg:GetXueTuCnt() + oOrg:GetMemberCnt()

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        mAnalyLog = table_combine(mAnalyLog, oPlayer:BaseAnalyInfo())
        analy.log_data("faction", mAnalyLog)
    else
        oWorldMgr:LoadProfile(iPid, function (oProfile)
            if oProfile then
                mAnalyLog = table_combine(mAnalyLog, oProfile:BaseAnalyInfo())
                analy.log_data("faction", mAnalyLog)        
            end
        end)
    end
end

function COrgMgr:IsBeXueTu(iGrade)
    if iGrade < 35 then return true end
end

function COrgMgr:SendMail2OrgMember(iOrg, bAll, iSender, sName, mMail)
    local oOrg = self:GetNormalOrg(iOrg)
    if not oOrg then return end

    oOrg:SendMail2Member(bAll, iSender, sName, mMail)
end

function COrgMgr:RenameNormalOrg(oPlayer, iOrg, sName)
    local oOrg = self:GetNormalOrg(iOrg)
    if not oOrg then return end

    local iPid = oPlayer:GetPid()
    if not oOrg:IsLeader(iPid) then return end

    if self:HasSameName(sName) then
        oPlayer:NotifyMessage(self:GetOrgText(1068))
        return
    end
    local iSid = 10179
    if oPlayer:GetItemAmount(iSid) < 1 then
        oPlayer:NotifyMessage(self:GetOrgText(1175))
        return 
    end
    oPlayer:RemoveItemAmount(iSid, 1, "帮派改名")
    self:ForceRenameOrg(iOrg, sName)
    local mNet = oOrg:PackMaskOrgMainInfo({name=oOrg:GetName()})
    oPlayer:Send("GS2COrgMainInfo", mNet)
    oPlayer:NotifyMessage(self:GetOrgText(1176))
    local mRole = oPlayer:RoleInfo({orgname=true})
    global.oNotifyMgr:SendGS2Org(iOrg, "GS2CPropChange", {role=mRole})

    local oMailMgr = global.oMailMgr
    local mData, sMailName = oMailMgr:GetMailInfo(3019)
    if mData then
        local mInfo = table_copy(mData)
        local mReplace = {role=oOrg:GetLeaderName(), bpname=sName}
        mInfo.context = global.oToolMgr:FormatColorString(mInfo.context, mReplace) 
        oOrg:SendMail2Member(true, 0, sMailName, mInfo)
    end
end

function COrgMgr:RenameReadyOrg(oPlayer, iOrg, sName)
    local oReadyOrg = self:GetReadyOrg(iOrg)
    if not oReadyOrg then return end

    if self:HasSameName(sName) then
        oPlayer:NotifyMessage(self:GetOrgText(1068))
        return
    end
    local iSid = 10179
    if oPlayer:GetItemAmount(iSid) < 1 then
        oPlayer:NotifyMessage(self:GetOrgText(1175))
        return 
    end
    oPlayer:RemoveItemAmount(iSid, 1, "帮派改名")
    self:ForceRenameReadyOrg(iOrg, sName)
    local oInterfaceMgr = global.oInterfaceMgr
    oInterfaceMgr:RefreshOrgRespond({infos={oReadyOrg:PackRespondInfo()}})
end

function COrgMgr:SetTestData(sKey, iVal)
    self.m_mTestData[sKey] = iVal
end

function COrgMgr:GetTestData(sKey)
    return self.m_mTestData[sKey]
end

function COrgMgr:GetOtherConfig(sKey)
    if self:GetTestData(sKey) then
        return self:GetTestData(sKey)
    end
    local res = require "base.res"
    return res["daobiao"]["org"]["others"][1][sKey]
end


