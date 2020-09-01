local global = require "global"
local extend = require "base.extend"
local record = require "public.record"
local net = require "base.net"
local res = require "base.res"

local loadsummon = import(service_path("summon/loadsummon"))
local clientnpc = import(service_path("task/clientnpc"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines"))
local behaviorevmgr = import(service_path("player/behaviorevmgr"))
local util = import(lualib_path("public.util"))

local templ = import(service_path("templ"))
local analylog = import(lualib_path("public.analylog"))

local random = math.random

local gsub = string.gsub

-- taskobj是虚基类，不能直接使用，故没有NewTask方法
CTask = {}
CTask.__index = CTask
CTask.m_sName = "base"
inherit(CTask, templ.CTempl)

function CTask:New(taskid)
    local o = super(CTask).New(self)
    o.m_ID = taskid
    o:Init()
    return o
end

function CTask:GetDirName()
    return self.m_sName
end

function CTask:Init()
    self.m_Owner = 0
    self.m_mEvent = {}
    self.m_mNeedItem = {}
    self.m_mNeedItemGroup = {}
    self.m_mNeedSummon = {}
    self.m_mClientNpc = {}
    self.m_mFollowNpc = {}
    self.m_mFollowNpcConfig = {}
    self.m_lUseTaskItem = {} -- 场景中使用虚拟道具
    self.m_lPickItem = {}    -- 场景中采集
    self.m_lPosQte = {}      -- 寻路去场景中触发QTE
end

function CTask:GetId()
    return self.m_ID
end

function CTask:Release()
    local pid = self.m_Owner
    self:DelTimeCb("timeout")

    self.m_mNeedItem = {}
    self.m_mNeedItemGroup = {}
    self.m_mNeedSummon = {}
    local oNpcMgr = global.oNpcMgr
    local mTmpNpcTable = self.m_mClientNpc
    self.m_mClientNpc = {}
    for _,oClientNpc in pairs(mTmpNpcTable) do
        oNpcMgr:RemoveObject(oClientNpc:ID())
        baseobj_safe_release(oClientNpc)
    end
    local mTmpNpcTable = self.m_mFollowNpc
    self.m_mFollowNpc = {}
    for _,oFollowNpc in pairs(mTmpNpcTable) do
        oNpcMgr:RemoveObject(oFollowNpc:ID())
        baseobj_safe_release(oFollowNpc)
    end

    -- PS：不可以在这里UnRegAnlei，1.任务Clear时已经处理过，2.如果当前身上又接取了同taskid的任务，会因为delay_release而受到影响
    -- if self:TaskType() == gamedefines.TASK_TYPE.TASK_ANLEI then
    --     self:UnRegAnlei()
    -- end

    if self.m_oBehaviorEvCtrl then
        self.m_oBehaviorEvCtrl:Clear()
        baseobj_safe_release(self.m_oBehaviorEvCtrl)
        self.m_oBehaviorEvCtrl = nil
    end

    super(CTask).Release(self)
end

function CTask:GetTaskBaseData( ... )
    local mData = res["daobiao"]["task"][self.m_sName] or {}
    return mData
end

function CTask:GetTaskExtData( ... )
    local mData = res["daobiao"]["task_ext"] or {}
    return mData
end


function CTask:GetTaskData()
    local mData = self:GetTaskBaseData()
    mData = mData["task"][self.m_ID]
    assert(mData,string.format("CTask GetTaskData err, taskid:%s, dir:%s, owner:%s",self.m_ID, self.m_sName, self:GetOwner()))
    return mData
end

function CTask:GetNpcGroupData(iGroup)
    local mData = res["daobiao"]["npcgroup"] or {}
    mData = mData[iGroup]
    assert(mData,string.format("CTask GetNpcGroupData err, npcgroupid:%d, taskid:%d, dir:%s, owner:%s",iGroup, self:GetId(), self.m_sName, self:GetOwner()))
    return mData["npc"]
end

function CTask:GetTempNpcData(iNpcType)
    local mData = self:GetTaskBaseData()
    local mData = mData["tasknpc"] or {}
    local mTempData = mData[iNpcType]
    assert(mTempData,string.format("CTask GetTempNpcData err, npctype:%d, taskid:%d, dir:%s, owner:%s",iNpcType, self:GetId(), self.m_sName, self:GetOwner()))
    return mTempData
end

function CTask:GetEventData(iEvent)
    local mData = self:GetTaskBaseData()
    mData = mData["taskevent"] or {}
    mData = mData[iEvent]
    assert(mData,string.format("CTask GetEventData err, eventid:%d, taskid:%d, dir:%s, owner:%s",iEvent, self:GetId(), self.m_sName, self:GetOwner()))
    return mData
end

function CTask:GetDialogData(iDialog)
    local mData = self:GetTaskBaseData()
    mData = mData["taskdialog"] or {}
    mData = mData[iDialog]
    assert(mData,string.format("CTask:GetDialogData err, dialogid:%d, taskid:%d, dir:%s, owner:%s",iDialog, self:GetId(), self.m_sName, self:GetOwner()))
    return table_deep_copy(mData["Dialog"])
end

function CTask:GetTaskItemData(itemsid)
    local mData = self:GetTaskExtData()
    local mData = mData["taskitem"]
    mData = mData[itemsid]
    assert(mData,string.format("CTask:GetTaskItem err, itemsid:%d, taskid:%d, dir:%s, owner:%s",itemsid, self:GetId(), self.m_sName, self:GetOwner()))
    return mData
end

function CTask:GetPickData(pickid)
    local mData = self:GetTaskExtData()
    local mData = mData["taskpick"]
    mData = mData[pickid]
    assert(mData,string.format("CTask:GetPickData err, pickid:%d, taskid:%d, dir:%s, owner:%s",pickid, self:GetId(), self.m_sName, self:GetOwner()))
    return mData
end

function CTask:GetSceneGroup(iGroup)
    local mData = res["daobiao"]["scenegroup"][iGroup]
    mData = mData["maplist"]
    assert(mData,string.format("CTask:scenegroup err, scenegroupid:%d, taskid:%d, dir:%s, owner:%s",iGroup, self:GetId(), self.m_sName, self:GetOwner()))
    return mData
end

function CTask:GetTextData(iText)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetTextData(iText, {"task_ext"})
end

function CTask:GetTollGateData(iFight)
    local mData = res["daobiao"]["fight"][self.m_sName]["tollgate"]
    return mData[iFight]
end

function CTask:GetMonsterData(iMonsterIdx)
    local mData = res["daobiao"]["fight"][self.m_sName]["monster"]
    return mData[iMonsterIdx]
end

function CTask:GetAssistData()
    local mData = self:GetTaskExtData()
    mData = mData["taskassist"][1]
    assert(mData,string.format("CTask:GetAssistData err, taskid:%d, dir:%s, owner:%s", self:GetId(), self.m_sName, self:GetOwner()))
    return mData
end

function CTask:CanDealTask(oPlayer)
    local sSys = taskdefines.TASK_SYS_OPEN[self.m_sName]
    if sSys and not global.oToolMgr:IsSysOpen(sSys, oPlayer) then
        return false
    end
    return true
end

--任务类型:寻人，寻物等
function CTask:TaskType()
    local mData = self:GetTaskData()
    return mData["tasktype"]
end

--玩法分类 Kind
function CTask:Type()
    local mData = self:GetTaskData()
    return mData["type"]
end

--寻路类型
function CTask:AutoType()
    local mData = self:GetTaskData()
    return mData["autotype"]
end

-- 自动提交
function CTask:AutoSubmit()
    local mData = self:GetTaskData()
    return mData["autoSubmit"]
end

-- FIXME 提高效率的使用方式是仅parse一次
function CTask:ParseDesc(mDescStrings)
    -- TODO 将所有的cmd提出来交给处理函数，然后统一替换
end

function CTask:Name()
    local mData = self:GetTaskData()
    return self:TransString(self.m_Owner,nil,mData["name"])
end

--目标描述
function CTask:TargetDesc()
    local mData = self:GetTaskData()
    return self:TransString(self.m_Owner,nil,mData["goalDesc"]) .. (self:TransStringFuncCounting(self.m_Owner, nil) or "")
end

--任务描述
function CTask:DetailDesc()
    local mData = self:GetTaskData()
    return self:TransString(self.m_Owner,nil,mData["description"])
end

-- 播放接取任务后剧情
function CTask:PlayAcceptPlots(pid, npcobj)
    local mData = self:GetTaskData()
    -- TODO 使用DisplayMgr管理一串剧情的播放与回调处理
    self.m_tmp_sPlots = "acceptPlots"
    self:DoScript(pid, npcobj, mData["acceptPlots"])
    self.m_tmp_sPlots = nil
end

function CTask:PlayDonePlots(pid, npcobj)
    local mData = self:GetTaskData()
    -- TODO 使用DisplayMgr管理一串剧情的播放与回调处理
    self:DoScript(pid, npcobj, mData["donePlots"])
end

function CTask:AcceptNpc()
    local mData = self:GetTaskData()
    return mData["acceptNpcId"]
end

--提交npc
function CTask:SubmitNpc()
    local mData = self:GetTaskData()
    local npctype = mData["submitNpcId"]
    if npctype and npctype > 0 then
        return npctype
    end
end

--设置行动目标
function CTask:SetTarget(npctype)
    self:SetData("Target",npctype)
    self:Refresh()
end

--行动目标
function CTask:Target()
    local iTarget = self:GetData("Target")
    if iTarget then
        return iTarget
    end
    for _,oClientNpc in ipairs(self.m_mClientNpc) do
        if oClientNpc:GetEvent() then
            return oClientNpc:Type()
        end
    end
    for npctype,iEvent in pairs(self.m_mEvent) do
        return npctype
    end
    return self:SubmitNpc()
end

function CTask:ConfigTimeOut()
    local mData = self:GetTaskData()
    local iTimeout = mData["timeout"] or 0
    self:SetTimer(iTimeout) -- 有任务改表后去除了超时
end

function CTask:Config(pid, npcobj, mArgs)
    self.m_bIniting = true
    local mData = self:GetTaskData()

    self:Dirty()
    local sConfig = mData["initConfig"]
    self:DoScript(pid,npcobj,sConfig)

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local lFollowNpcs = mData["follownpcs"]
    if lFollowNpcs then
        for _, npctype in ipairs(lFollowNpcs) do
            local oFollowNpc = self:CreateFollowNpc(npctype, pid)
            if oFollowNpc and oPlayer then
                local iConfig = self:GetFollowNpcConfig(npctype, "new")
                if iConfig then
                    local mConfNet = {shape = oFollowNpc:Shape(), config = iConfig}
                    oPlayer:Send("GS2CConfigTaskFollowNpc", mConfNet)
                end
            end
        end
    end

    self:SubConfig(pid, mArgs)
    self.m_bIniting = false
end

function CTask:HasFollowNpc()
    return next(self.m_mFollowNpc)
end

function CTask:SubConfig(pid)
end

-- @Overrideable
function CTask:CheckDirectlyDone(npcobj)
    return self:CheckTaskReached()
end

function CTask:GetOwner()
    return self.m_Owner
end

function CTask:SetOwner(iOwner)
    self.m_Owner = iOwner
end

-- TODO 改为cron
function CTask:CheckTimeCb()
    self:SetupTimer()

    for npcid, oFollowNpc in pairs(self.m_mFollowNpc) do
        oFollowNpc:CheckTimeCb()
    end
    for _,oClientNpc in ipairs(self.m_mClientNpc) do
        oClientNpc:CheckTimeCb()
    end
end

function CTask:SetupTimer()
    -- TODO 改为cron
    self:DelTimeCb("timeout")
    local iTime = self:LeftTime()
    if not iTime then return end
    local iDelay
    if iTime <= 0 then
        iDelay = 1
    elseif iTime > 1 * 24 * 3600 then
        return
    else
        iDelay = iTime * 1000
    end
    assert(iTime<=10*24*3600, string.format("task lefttime too huge until crontab, taskid:%s, owner:%s, livetime:%d", self:GetId(), self:GetOwner(), iTime))
    local fCbSelfGetter = self:GetCbSelfGetter()
    if fCbSelfGetter then
        self:AddTimeCb("timeout", iDelay, function()
            local oTask = fCbSelfGetter()
            if oTask then
                oTask:TimeOut()
            end
        end)
    end
end

-- @Override
function CTask:GetCbSelfGetter()
    local iPid = self:GetOwner()
    local iTaskid = self:GetId()
    -- TODO 应该要加session检验，防止任务回调太晚，接到了同id的任务
    return function()
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then
            return
        end
        return oPlayer.m_oTaskCtrl:GetTask(iTaskid)
    end
end

function CTask:SetTimer(iSec, bSetup)
    if iSec > 0 then
        local iEndTime = get_time() + iSec
        self:SetData("Time", iEndTime)
    else
        self:SetData("Time", nil)
    end
    if bSetup then
        self:SetupTimer()
        self:Refresh({time = 1})
    end
end

function CTask:Timer()
    local iLeftTime = self:LeftTime()
    return iLeftTime or 0
end

function CTask:LeftTime()
    local iEndTime = self:GetData("Time")
    local iNowTime = get_time()
    if not iEndTime then
        return nil
    end
    if iEndTime > iNowTime then
        return iEndTime - iNowTime
    end
    return 0
end

function CTask:Setup()
    self:SetupTimer()
    self:TouchBehaviorCtrl()
    self:TouchAnleiCtrl()
end

function CTask:GetCreateTime()
    return self.m_iCreateTime
end

function CTask:SetCreateTime()
    self.m_iCreateTime = get_time()
end

function CTask:TimeOut()
    self.m_bIsTimeout = true
    self:FullRemove()
end

function CTask:IsTimeOut()
    local iEndTime = self:GetData("Time")
    if iEndTime and iEndTime <= get_time() then
        return true
    end
    return false
end

function CTask:Save()
    local mData = {}
    mData["isdone"] = self.m_bIsDone
    mData["create_time"] = self.m_iCreateTime
    mData["needitem"] = table_to_db_key(self.m_mNeedItem)
    mData["needitemgroup"] = table_to_db_key(self.m_mNeedItemGroup)
    mData["needsum"] = table_to_db_key(self.m_mNeedSummon)
    local lClientNpc = {}
    for _,oClientNpc in ipairs(self.m_mClientNpc) do
        table.insert(lClientNpc,oClientNpc:Save())
    end
    local lFollowNpc = {}
    for npcid,oFollowNpc in pairs(self.m_mFollowNpc) do
        table.insert(lFollowNpc, oFollowNpc:Save())
    end
    mData["clientnpc"] = lClientNpc
    mData["follownpc"] = lFollowNpc
    if next(self.m_mFollowNpcConfig) then
        mData["follownpcconfig"] = table_to_db_key(self.m_mFollowNpcConfig)
    end
    mData["event"] = table_to_db_key(self.m_mEvent)
    mData["taskitem"] = self.m_lUseTaskItem
    mData["taskitemsum"] = self.m_iUseTaskItemSum
    mData["taskpick"] = self.m_lPickItem
    mData["taskpicksum"] = self.m_iPickItemSum
    mData["posqte"] = self.m_lPosQte
    mData["needbehave"] = self.m_mBehaviorCnt
    mData["data"] = self.m_mData
    return mData
end

function CTask:Load(mData)
    if not mData then
        return
    end
    self.m_bIsDone = mData["isdone"]
    self.m_iCreateTime = mData["create_time"]
    local mClient = mData["clientnpc"] or {}
    for _,data in ipairs(mClient) do
        local oClientNpc = clientnpc.TouchNewClientNpc(data)
        if oClientNpc then
            global.oNpcMgr:AddObject(oClientNpc)
            table.insert(self.m_mClientNpc, oClientNpc)
        end
    end
    local mFollow = mData["follownpc"] or {}
    for _, mArgs in ipairs(mFollow) do
        self:SetNewFollowNpcByArgs(mArgs)
    end
    local mFollowConfig = mData["follownpcconfig"] or {}
    if next(mFollowConfig) then
        self.m_mFollowNpcConfig = table_to_int_key(mFollowConfig)
    end
    local mNeedItem = mData["needitem"] or {}
    for sid,iAmount in pairs(mNeedItem) do
        sid = tonumber(sid)
        self.m_mNeedItem[sid] = iAmount
    end
    local mNeedItemGroup = mData["needitemgroup"] or {}
    for groupid,iAmount in pairs(mNeedItemGroup) do
        groupid = tonumber(groupid)
        self.m_mNeedItemGroup[groupid] = iAmount
    end
    local mNeedSummon = mData["needsum"] or {}
    for sumid,iAmount in pairs(mNeedSummon) do
        sumid = tonumber(sumid)
        self.m_mNeedSummon[sumid] = iAmount
    end
    self.m_mData = mData["data"] or {}
    self.m_lUseTaskItem = mData["taskitem"] or {} -- list
    self.m_iUseTaskItemSum = mData["taskitemsum"] or 0
    self.m_lPickItem = mData["taskpick"] or {} -- list
    self.m_iPickItemSum = mData["taskpicksum"] or 0
    self.m_lPosQte = mData["posqte"] or {}
    self.m_mBehaviorCnt = mData["needbehave"]
    local mEvent = mData["event"] or {} -- hashtable
    for npctype,iEvent in pairs(mEvent) do
        self.m_mEvent[tonumber(npctype)] = iEvent
    end
    local mAnlei = {}
    for sMapId,data in pairs(self:GetData("anlei",{})) do
        mAnlei[tonumber(sMapId)] = data
    end
    self:SetData("anlei",mAnlei)
end

function CTask:Remove()
    local iPid = self:GetOwner()
    self:Detach()
    self:Clear(iPid)
end

function CTask:Detach()
    self:DelTimeCb("timeout")
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer.m_oTaskCtrl:RemoveTask(self)
    end
end

-- 做为外部接口使用，考虑到Remove与Release在完成时中间有DoScript逻辑，提供一个单独接口
function CTask:FullRemove()
    self:Remove()
    baseobj_delay_release(self)
end

-- 纯清理任务
function CTask:ClearlyFullRemove()
    self.m_bClearly = true
    self:FullRemove()
end

function CTask:Clear(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local mBianshenArgs = self:GetData("bianshen")
    if mBianshenArgs then
        if oPlayer then
            self:DelBianShenByKey(oPlayer, mBianshenArgs)
        end
    end
    local oNpcMgr = global.oNpcMgr
    -- 需要移除身上的followers
    if self:HasFollowNpc() then
        for npcid, oNpc in pairs(self.m_mFollowNpc) do
            if oPlayer then
                local iNpcType = oNpc:Type()
                local iConfig = self:GetFollowNpcConfig(iNpcType, "del")
                if iConfig then
                    local mConfNet = {shape = oNpc:Shape(), config = iConfig}
                    oPlayer:Send("GS2CConfigTaskFollowNpc", mConfNet)
                end
            end
            oNpcMgr:RemoveObject(npcid)
            baseobj_delay_release(oNpc)
        end
        self.m_mFollowNpc = {}
        if oPlayer then
            oPlayer.m_oTaskCtrl:RefreshFollowNpcs()
        end
    end
    if self:TaskType() == gamedefines.TASK_TYPE.TASK_ANLEI then
        oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:UnregWholeTask(self:GetId())
    end
end

function CTask:Abandon(oPlayer)
    self:FullRemove()
end

function CTask:Commit(npcobj, mArgs)
    self:MissionDone(npcobj, mArgs)
end

function CTask:RewardMissionDone(pid, npcobj, mRewardArgs)
    local mData = self:GetTaskData()
    local s = mData["submitRewardStr"]
    self:DoScript(pid,npcobj,s, mRewardArgs)
end

-- -- TODO 似乎无用，多检查一下，看看是否可以删
-- function CTask:GetRewardArgs()
--     return nil
-- end

function CTask:TryMissionDone(npcobj, mArgs)
    if self:IsForbidSubmit() then
        return false
    end
    self:MissionDone(npcobj, mArgs)
    return true
end

function CTask:MissionDone(npcobj, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        oPlayer.m_oTaskCtrl:MissionDone(self, npcobj, mArgs)
    end
end

function CTask:TmpSetNext(iTaskid)
    self.m_tmp_iNextTask = iTaskid
end

function CTask:TmpGetNext()
    -- 如果任务先执行DONE再执行NT，m_tmp_iNextTask便没有设值
    return self.m_tmp_iNextTask or self:GetTaskData()._next_task
end

function CTask:NextTask(iTaskid, pid, npcobj, mArgs)
    self:TmpSetNext(iTaskid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer.m_oTaskCtrl:NextTask(self, iTaskid, npcobj, mArgs)
    end
end

function CTask:MissionUnReach(npcobj, mArgs)
    if not self.m_tmp_bReach then
        return
    end
    self.m_tmp_bReach = nil
    self:SendReach()
end

-- @return: bDoneMission
function CTask:MissionReach(npcobj, mArgs)
    self.m_tmp_bReach = true

    if self:AutoSubmit() == 1 then
        if self:TryMissionDone(npcobj, mArgs) then
            return true
        end
    end
    self:SendReach()
end

function CTask:OnMissionDone(pid)
end

function CTask:AfterMissionDone(pid)
end

-- @Overrideable
-- 下行用
function CTask:PackIsDone()
    return self:GetDone()
end

function CTask:GetDone()
    return self.m_bIsDone or 0
end

function CTask:IsDone()
    return self.m_bIsDone
end

function CTask:SetDone()
    self:Dirty()
    self.m_bIsDone = 1
end

function CTask:GetLinkId()
    local iInheritLinkId = self:GetData("linkid")
    if iInheritLinkId then
        return iInheritLinkId
    end
    local iConfigLinkId = self:GetTaskData().linkid
    if iConfigLinkId and iConfigLinkId > 0 then
        return iConfigLinkId
    end
end

function CTask:SetLinkId(iLinkId)
    return self:SetData("linkid", iLinkId)
end

function CTask:GetRewardAddition(oAwardee)
    -- formula_string有坑，因为闭包缓存，m参数不能删key，否则读取上次调用的值
    return {itemstar = self.m_tmp_iSubmitItemStar or 0}
end

-- @Override
function CTask:MakeMonsterModelByConfig(mMonsterData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    return self:PackModelInfo(mMonsterData, oPlayer)
end

function CTask:GetNpcRandomName()
    return global.oToolMgr:GenRandomNpcName()
end

function CTask:BuildClientNpcArgs(iNpcType, pid, bPos)
    local oSceneMgr = global.oSceneMgr
    local mData = self:GetTempNpcData(iNpcType)
    local iNameType = mData["nameType"]
    local sName
    if iNameType == 2 then
        sName = self:GetNpcName(iNpcType)
    elseif iNameType == 3 then
        sName = self:GetNpcRandomName()
        if sName == "" then
            sName = mData["name"]
        end
    else
        sName = mData["name"]
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local mModel = self:PackModelInfo(mData, oPlayer)
    local iMapId
    local mPosInfo
    if bPos then
        local x,y
        iMapId = mData["mapid"]
        if iMapId < 1000 then
            local mMapList = self:GetSceneGroup(iMapId)
            iMapId = mMapList[random(#mMapList)]
            x, y = oSceneMgr:RandomPos2(iMapId)
        else
            if mData["x"] <= 0 then
                x, y = oSceneMgr:RandomPos2(iMapId)
            else
                x = mData["x"]
                y = mData["y"]
            end
        end
        mPosInfo = {
            x = x,
            y = y,
            z = mData["z"],
            face_x = mData["face_x"] or 0,
            face_y = mData["face_y"] or 0,
            face_z = mData["face_z"] or 0,
        }
    end
    local iLifeTime = mData["life_time"]
    local iLifeEnd
    if iLifeTime and iLifeTime > 0 then
        iLifeEnd = iLifeTime + get_time()
    end
    local mArgs = {
        type = mData["id"],
        func_group = self:NpcFuncGroup("task"),
        name = sName,
        title = mData["title"],
        map_id = iMapId,
        pos_info = mPosInfo,
        model_info = mModel,
        event = mData["event"] or 0,
        reuse = mData["reuse"] or 0,
        xunluo_id = mData["xunluo_id"],
        dialogId = mData["dialogId"],
        taskid = self.m_ID,
        owner = self:GetOwner(),
        life_end = iLifeEnd,
        ghost_eye = mData["ghost_eye"],
        no_turnface = mData["no_turnface"],
    }
    return mArgs
end

function CTask:CreateClientMirrorNpc(iNpcType, pid, npcobj)
    self:Dirty()
    local oMirror = self:FindMirrorMonster(nil, npcobj)
    local oClientNpc = self:CreateClientNpc(iNpcType, pid)
    if oMirror then
        oClientNpc:SaveMirrorInfo(self:PackMirrorInfo(oMirror))
    end
    return oClientNpc
end

-- @Overrideable 不同玩法镜像来源数据可能不同
function CTask:PackMirrorInfo(oMirror)
    local mData = {
        name = oMirror:GetName(),
        grade = oMirror:GetGrade(),
        model_info = oMirror:GetModelInfo(),
    }
    local oSumm = oMirror.m_oSummonCtrl:GetFightSummon()
    if oSumm then
        mData.summ = {
            name = oSumm:Name(),
            grade = oSumm:Grade(),
            model_info = oSumm:GetModelInfo(),
        }
    end
    mData.ext = self:PackMirrorExtInfo(oMirror)
    return mData
end

function CTask:PackMirrorExtInfo(oMirror)
    return nil
end

function CTask:CreateClientNpc(iNpcType, pid)
    self:Dirty()
    local mArgs = self:BuildClientNpcArgs(iNpcType, pid, true)
    local oClientNpc = clientnpc.TouchNewClientNpc(mArgs)
    if oClientNpc then
        global.oNpcMgr:AddObject(oClientNpc)
        table.insert(self.m_mClientNpc, oClientNpc)
    end
    return oClientNpc
end

function CTask:ChangeClientNpcPos(oClientNpc, iMap, x, y)
    self:Dirty()
    local mPosInfo = oClientNpc:GetPos()
    mPosInfo.x = x
    mPosInfo.y = y
    oClientNpc:SetPos(mPosInfo)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        oPlayer:Send("GS2CRefreshTaskClientNpc", {
            taskid = self:GetId(),
            clientnpc = self:PackOneClientNpc(oClientNpc),
        })
    end
end

function CTask:RefreshTaskClientNpc(oClientNpc)
    local mClientNpcInfo = self:PackOneClientNpc(oClientNpc)
    local iTaskId = self:GetId()
    local mNet = {
        taskid = iTaskId,
        clientnpc = mClientNpcInfo,
    }
    self:PostOwners("GS2CRefreshTaskClientNpc", mNet)
end

function CTask:PostOwners(sNetCmd, mNet)
    local iPid = self:GetOwner()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send(sNetCmd, mNet)
    end
end

function CTask:ReRandClientNpcPos(oClientNpc)
    local iMapId = oClientNpc:GetMap()
    if not iMapId then return end
    local x, y = global.oSceneMgr:RandomPos2(iMapId)
    self:ChangeClientNpcPos(oClientNpc, iMapId, x, y)
end

function CTask:SetNewFollowNpcByArgs(mArgs)
    local oFollowNpc = clientnpc.TouchNewFollowNpc(mArgs)
    if oFollowNpc then
        self:Dirty()
        global.oNpcMgr:AddObject(oFollowNpc)
        self.m_mFollowNpc[oFollowNpc:ID()] = oFollowNpc
    end
    return oFollowNpc
end

function CTask:ConfigFollowNpc(npctype, mConfig)
    self.m_mFollowNpcConfig[npctype] = mConfig
    self:Dirty()
end

function CTask:GetFollowNpcConfig(npctype, sKey)
    local mConfig = self.m_mFollowNpcConfig[npctype]
    if mConfig then
        local iConfig = mConfig[sKey]
        if iConfig then
            return iConfig
        end
    end
end

function CTask:CreateFollowNpc(iNpcType, pid)
    self:Dirty()
    local mArgs = self:BuildClientNpcArgs(iNpcType, pid, false)
    local oFollowNpc = self:SetNewFollowNpcByArgs(mArgs)
    return oFollowNpc
end

function CTask:RemoveFollowNpc(npcobj)
    if not npcobj then
        return
    end
    local npcid = npcobj:ID()
    local oFollowNpc = self.m_mFollowNpc[npcid]
    if not oFollowNpc then
        return
    end
    self:Dirty()
    self.m_mFollowNpc[npcid] = nil
    global.oNpcMgr:RemoveObject(npcid)
    baseobj_delay_release(npcobj)
    local mNet = {
        taskid = self:GetId(),
        npcid = npcid,
    }
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    local iNpcType = oFollowNpc:Type()
    local iConfig = self:GetFollowNpcConfig(iNpcType, "del")
    if iConfig then
        local mConfNet = {shape = oFollowNpc:Shape(), config = iConfig}
        oPlayer:Send("GS2CConfigTaskFollowNpc", mConfNet)
    end
    -- oPlayer:Send("GS2CRemoveTaskFollowNpc", mNet)
    oPlayer.m_oTaskCtrl:RefreshFollowNpcs()
end

function CTask:RemoveClientNpc(npcobj)
    if not npcobj then
        return
    end
    local iIdx
    local npcid = npcobj.m_ID
    for idx, oClientNpc in ipairs(self.m_mClientNpc) do
        if oClientNpc.m_ID == npcid then
            iIdx = idx
            break
        end
    end
    if not iIdx then
        return
    end
    self:Dirty()
    table.remove(self.m_mClientNpc, iIdx)
    global.oNpcMgr:RemoveObject(npcid)
    baseobj_delay_release(npcobj)
    local mNet = {}
    mNet["taskid"] = self.m_ID
    mNet["npcid"] = npcid
    mNet["target"] = self:GetTargetNpcType()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CRemoveTaskNpc",mNet)
    self:Refresh()
end

function CTask:GetTargetNpcType()
    local iType = self:Target()
    if iType then
        local oTargetNpc = self:GetNpcObjByType(iType)
        if oTargetNpc then
            return oTargetNpc:Type()
        end
    end
end

function CTask:GetClientObj(npcid)
    for _,oClientNpc in pairs(self.m_mClientNpc) do
        if oClientNpc.m_ID == npcid then
            return oClientNpc
        end
    end
end

function CTask:IsVisible(oPlayer)
    return global.oTaskHandler:IsTaskVisible(oPlayer, self:GetId())
end

--前置条件
function CTask:PreCondition(oPlayer)
    return true
end

function CTask:SetNeedItemGroup(lItemGroupIds, iAmount)
    local iItemGroupId = lItemGroupIds[random(#lItemGroupIds)]
    self.m_mNeedItemGroup[iItemGroupId] = iAmount
    self:Dirty()
end

function CTask:GetItemName(itemSid)
    if itemSid < 1000 then
        return global.oItemLoader:GetItemGroupName(itemSid)
    else
        return global.oItemLoader:GetItemNameBySid(itemSid)
    end
end

function CTask:SetNeedItem(itemGroupId,iAmount)
    self:Dirty()
    local sid
    if itemGroupId < 1000 then
        local lItemSids = global.oItemLoader:GetItemGroup(itemGroupId)
        sid = extend.Random.random_choice(lItemSids)
    else
        sid = itemGroupId
    end
    self.m_mNeedItem[sid] = iAmount
end

function CTask:SetNeedSummonFromGroup(pid, iSummGroupId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    local iSummSid
    if iSummGroupId < 1000 then
        local lSummSids = loadsummon.GetTaskSubmitableSummonGroup(oPlayer, iSummGroupId)
        iSummSid = lSummSids[random(#lSummSids)]
    else
        iSummSid = iSummGroupId
    end
    self:SetNeedSummonSid(pid, iSummSid)
end

function CTask:SetNeedSummonSid(pid, iSummSid)
    self:Dirty()
    self.m_mNeedSummon[iSummSid] = 1
end

function CTask:NeedItem()
    return self.m_mNeedItem
end

function CTask:NeedItemGroup()
    return self.m_mNeedItemGroup
end

function CTask:NeedSummon()
    return self.m_mNeedSummon
end

function CTask:IsPosNear(oPlayer, iMapid, iX, iY)
    local oNowScene = oPlayer:GetNowScene()
    local mNowPos = oPlayer:GetNowPos()
    if not oNowScene or oNowScene:MapId() ~= iMapid then
        return false
    end
    if not mNowPos then
        return false
    end
    -- if iX and math.abs(mNowPos.x - iX) > 9 then
    --     return false
    -- end
    -- if iY and math.abs(mNowPos.y - iY) > 9 then
    --     return false
    -- end
    return true
end

function CTask:SetToUseTaskItem(map_id,x,y,radius,itemsid)
    self:Dirty()
    local mData = {
        itemid = itemsid,
        map_id = map_id,
        pos_x = x,
        pos_y = y,
        radius = radius,
    }
    table.insert(self.m_lUseTaskItem, mData)
    self.m_iUseTaskItemSum = 1 + (self.m_iUseTaskItemSum or 0)
end

--随机场景使用任务道具组中随机道具
function CTask:SetRanScTaskItem(map_id,radius,itemGroupId)
    local oSceneMgr = global.oSceneMgr
    if map_id < 100000 then
        local maplist = self:GetSceneGroup(map_id)
        map_id = maplist[random(#maplist)]
    end
    local itemsid = itemGroupId
    if itemGroupId < 1000 then
        local lItemGroup = global.oItemLoader:GetItemGroup(itemGroupId)
        itemsid = lItemGroup[random(#lItemGroup)]
    end
    -- 将随机的结果固定下来
    local x,y = oSceneMgr:RandomPos2(map_id)

    self:SetToUseTaskItem(map_id,x,y,radius,itemsid)
end

--采集
function CTask:SetPick(iMapId,iPickId,iCnt,lPos)
    lPos = lPos or {}
    local oSceneMgr = global.oSceneMgr
    self:Dirty()
    for iPos = 1,iCnt do
        local mPos = lPos[iPos]
        local x,y
        if mPos then
            x,y = table.unpack(mPos)
        else
            x,y = oSceneMgr:RandomPos2(iMapId)
        end
        local mData = {
            pickid = iPickId,
            map_id = iMapId,
            pos_x = x,
            pos_y = y,
        }
        table.insert(self.m_lPickItem,mData)
    end
    self.m_iPickItemSum = iCnt + (self.m_iPickItemSum or 0)
end

function CTask:StepPickTask(oPlayer, iRestStep)
    local lPickInfo = self.m_lPickItem
    if table_count(lPickInfo) ~= (iRestStep + 1) then
        self:GS2CAddTask(oPlayer:GetPid())
        return
    end
    local mPickData = lPickInfo[1]
    if not mPickData then
        self:MissionDone()
        return
    end
    if not self:IsPosNear(oPlayer, mPickData.map_id) then
        self:GS2CAddTask(oPlayer:GetPid())
        return
    end
    table.remove(lPickInfo, 1)
    self:Dirty()
    if iRestStep == 0 then
        self:MissionDone()
    else
        self:Refresh()
    end
end

function CTask:StepItemUseTask(oPlayer, iRestStep)
    local lItemInfo = self.m_lUseTaskItem
    if table_count(lItemInfo) ~= (iRestStep + 1) then
        self:GS2CAddTask(oPlayer:GetPid())
        return
    end
    local mItemData = lItemInfo[1]
    if not mItemData then
        self:MissionDone()
        return
    end
    if not self:IsPosNear(oPlayer, mItemData.map_id) then
        self:GS2CAddTask(oPlayer:GetPid())
        return
    end
    table.remove(lItemInfo, 1)
    self:Dirty()
    if iRestStep == 0 then
        self:MissionDone()
    else
        self:Refresh()
    end
end

function ParseSetting(lArgs)
    local mSettings = {}
    for _,sArgs in ipairs(lArgs) do
        local key,value = string.match(sArgs,"(.+)=(.+)")
        local iValue = tonumber(value)
        if iValue then
            value = iValue
        end
        mSettings[key] = value
    end
    return mSettings
end

function CTask:SetAttr(mArgs)
    for key, value in pairs(ParseSetting(mArgs)) do
        self:SetData(key,value)
    end
end

function CTask:SetConditions(mArgs)
    local mCondi = self:GetData("conditions", {})
    mCondi = table_combine(mCondi, ParseSetting(mArgs))
    self:SetData("conditions", mCondi)
end

function CTask:UnlockTag(iTag)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:UnlockTag(iTag)
end

function CTask:LinkDone(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:RecLinkDone(self.m_sName, self:GetLinkId())
end

function CTask:QuickTeamup(pid, iAutoTargetId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oActiveCtrl:QuickTeamup(oPlayer, iAutoTargetId)
end

function CTask:CanCallOrgHelp(oPlayer)
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        local sMsg = self:GetTextData(1022)
        oPlayer:NotifyMessage(sMsg)
        return false
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local pid = oPlayer:GetPid()
        if not oTeam:IsLeader(pid) then
            local sMsg = self:GetTextData(1021)
            oPlayer:NotifyMessage(sMsg)
            return false
        end
    end
    return true
end

function CTask:DoCallOrgHelp(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then
        local oTeamMgr = global.oTeamMgr
        oTeamMgr:CreateTeam(oPlayer:GetPid())
    end
    local sMsg = self:GetOrgHelpMsg(oPlayer)
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleOrgChat(oPlayer, sMsg)
end

function CTask:CallOrgHelp(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if not self:CanCallOrgHelp(oPlayer) then
        return
    end
    if oPlayer.m_oThisTemp:Query("call_org_help") then
        local sMsg = self:GetTextData(1023)
        oPlayer:NotifyMessage(sMsg)
        return
    end
    local iCd = 10 -- 定额CD时间
    oPlayer.m_oThisTemp:Set("call_org_help", true, iCd)
    self:DoCallOrgHelp(oPlayer)
end

function CTask:GetKindShowName()
    return global.oTaskLoader:GetKindShowName(self:Type()) or self.m_sTempName
end

function CTask:GetOrgHelpMsg(oPlayer)
    local sPlayerName = oPlayer:GetName()
    local sTaskName = self:Name()
    local iTeamID = oPlayer:TeamID()
    local sKindShowName = self:GetKindShowName()
    local sMsg =  self:GetTextData(1024)
    return global.oToolMgr:FormatColorString(sMsg, {role = sPlayerName, task_kind = sKindShowName, task_name = sTaskName, teamid = iTeamID})
end

function CTask:DelBianShenByKey(oPlayer, mBianshenArgs)
    oPlayer:DelBianShen(mBianshenArgs)
end

function CTask:BianShen(pid, iBianshenId, iSec)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local mSource = {id = self:GetId(), type = "task"}
    if oPlayer:BianShen(iBianshenId, iSec, nil, gamedefines.BIANSHEN_GROUP.TASK, mSource) then
        self:SetData("bianshen", {
            id = iBianshenId,
            group = gamedefines.BIANSHEN_GROUP.TASK,
            source = mSource,
        })
    end
end

function CTask:SendRewardMail(pid, iMailId, iRewardId, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    global.oMailMgr:SendMailReward(oPlayer, iMailId, iRewardId, self.m_sName, mArgs)
end

function CTask:SetNpcVisible(pid, lNpcTypes, bVisible)
    if not next(lNpcTypes) then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SetNpcVisible(oPlayer, lNpcTypes, bVisible)
end

function CTask:SetSceneEffectVisible(pid, lSEffIds, bVisible)
    if not next(lSEffIds) then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SetSceneEffectVisible(oPlayer, lSEffIds, bVisible)
end

function CTask:SetGhostEye(pid, iOpen)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SetGhostEye(oPlayer, iOpen)
end

function CTask:PlayStoryAnimeFight(pid, iAnimeId, oNpc)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:PlayStoryAnimeFight(iAnimeId, self:GetId(), oNpc:ID())
end

function CTask:OnAnimeFightEnd(oPlayer, npcid, iAnswer)
    if iAnswer ~= 1 then
        return
    end
    local iEvent = self:GetEvent(npcid)
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end
    local pid = oPlayer:GetPid()
    local oNpc = self:GetNpcObj(npcid)
    self:DoScript(pid, oNpc, mEvent["win"])
end

function CTask:PlayStoryAnime(pid, iAnimeId)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer.m_oTaskCtrl:PlayStoryAnime(iAnimeId)
end

function CTask:SetBehaviors(pid, lBehaviors, iCnt)
    if self:IsTeamTask() then
        return
    end
    if self.m_mBehaviorCnt then
        return
    end
    self.m_mBehaviorCnt = {
        behaviors = table_copy(lBehaviors),
        max_cnt = iCnt,
        done_cnt = 0,
    }
    self:Dirty()
    if self.m_oBehaviorEvCtrl then
        self.m_oBehaviorEvCtrl:Clear()
        baseobj_delay_release(self.m_oBehaviorEvCtrl)
        self.m_oBehaviorEvCtrl = nil
    end
    self:TouchBehaviorCtrl()
end

function CTask:TouchBehaviorCtrl()
    if self:IsTeamTask() then
        return
    end
    local pid = self:GetOwner()
    if not pid or pid <= 0 then
        return
    end
    local mBehaviorInfo = self.m_mBehaviorCnt
    if not mBehaviorInfo then
        return
    end
    if self.m_oBehaviorEvCtrl then
        return
    end
    local fSelfGetter = self:GetCbSelfGetter()
    if not fSelfGetter then
        return
    end
    local iMaxCnt = mBehaviorInfo.max_cnt or 0
    local iDoneCnt = mBehaviorInfo.done_cnt or 0
    if iDoneCnt >= iMaxCnt then
        return
    end
    local fCallback = function(iEvType, mData, iPid)
        local oTask = fSelfGetter()
        if oTask then
            oTask:OnBehaviorEvTrigger(iEvType, mData)
        end
    end
    local lBehaviors = self.m_mBehaviorCnt.behaviors
    self.m_oBehaviorEvCtrl = behaviorevmgr.NewBehaviorEvCtrl(pid, fCallback)
    self.m_oBehaviorEvCtrl:TouchRegBehaviorEvs(lBehaviors)
end

function CTask:OnBehaviorEvTrigger(iEvType, mData)
    if not self.m_mBehaviorCnt then
        return
    end
    if not self.m_oBehaviorEvCtrl then
        return
    end

    local mTriggerTimes = self.m_oBehaviorEvCtrl:TriggerBehaviorEvent(iEvType, mData)
    local lBehaviors = self.m_mBehaviorCnt.behaviors
    if not lBehaviors then
        return
    end
    local iTimes = 0
    for _, iBehavior in ipairs(lBehaviors) do
        local iCnt = mTriggerTimes[iBehavior]
        if iCnt then
            iTimes = iTimes + iCnt
        end
    end
    if iTimes == 0 then
        return
    end
    self:Dirty()
    local mBehaviorInfo = self.m_mBehaviorCnt
    local iMaxCnt = mBehaviorInfo.max_cnt
    local iNewCnt = (mBehaviorInfo.done_cnt or 0) + iTimes
    if iNewCnt > iMaxCnt then
        iNewCnt = iMaxCnt
    end
    mBehaviorInfo.done_cnt = iNewCnt
    self:Refresh()
    if iNewCnt >= iMaxCnt then
        --self.m_oBehaviorEvCtrl:Clear()
        baseobj_delay_release(self.m_oBehaviorEvCtrl)
        self.m_oBehaviorEvCtrl = nil

        local npctype = self:Target()
        if not npctype then
            self:MissionDone()
        else
            self:MissionReach()
        end
    end
end

function CTask:IsBehaviorFullDone()
    if not self.m_mBehaviorCnt then
        return true
    end
    local lBehaviors = self.m_mBehaviorCnt.behaviors
    if not lBehaviors or 0 == #lBehaviors then
        return true
    end
    local iMaxCnt = self.m_mBehaviorCnt.max_cnt or 0
    local iDoneCnt = self.m_mBehaviorCnt.done_cnt or 0
    return iDoneCnt >= iMaxCnt
end

function CTask:DoBehavior(oPlayer)
    if not self.m_mBehaviorCnt then
        return
    end
    local lBehaviors = self.m_mBehaviorCnt.behaviors
    local iBehavior = extend.Random.random_choice(lBehaviors)
    if not iBehavior then
        return
    end
    oPlayer:Send("GS2CGuideBehavior", {behavior = iBehavior})
end

function CTask:IsLogTaskWanfa()
    return false
end

function CTask:LogTaskWanfaInfo(oPlayer, iOperate)
    if self:IsLogTaskWanfa() then
        analylog.LogWanFaInfo(oPlayer, self.m_sName, self:GetId(), iOperate)
    end
end

function CTask:OnAddDone(oPlayer)
    self.m_bIniting = nil
end

function CTask:GS2CAddTask(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CAddTask",{
        taskdata = self:PackTaskInfo()
    })
end

function CTask:ValidDoScript(pid)
    local iOwner = self:GetOwner()
    assert(pid == iOwner, string.format("task DoScript err, owner:%s,pid:%s", iOwner, pid))
    return true
end

function CTask:DoScript2(pid, npcobj, s, mArgs)
    local sScriptFunc = string.match(s, "^([$%a]+)")
    if sScriptFunc then
        local sArgs = string.sub(s, #sScriptFunc + 1, -1)

        if sScriptFunc == "DONE" then
            -- 完成任务
            self:MissionDone(npcobj, mArgs)
            return true
        elseif sScriptFunc == "NT" then
            -- 发下一步任务
            local iTaskid = sArgs
            iTaskid = tonumber(iTaskid)
            self:NextTask(iTaskid, pid, npcobj, mArgs)
            return true
        elseif sScriptFunc == "TI" then
            -- 使用虚拟道具
            local mArgs = split_string(sArgs,":", tonumber)
            local map_id,x,y,radius,itemsid = table.unpack(mArgs)
            self:SetToUseTaskItem(map_id,x,y,radius,itemsid)
            return true
        elseif sScriptFunc == "GTI" then
            -- 随机场景组中使用任务道具
            local mArgs = split_string(sArgs,":", tonumber)
            local map_id,radius,itemGroupId = table.unpack(mArgs)
            self:SetRanScTaskItem(map_id,radius,itemGroupId)
            return true
        elseif sScriptFunc == "SET" then
            sArgs = string.sub(sArgs, 2, -2)
            local mArgs = split_string(sArgs,"|")
            self:SetAttr(mArgs)
            return true
        elseif sScriptFunc == "SETC" then
            -- 设置Condition
            sArgs = string.sub(sArgs, 2, -2)
            local mArgs = split_string(sArgs,"|")
            self:SetConditions(mArgs)
            return true
        elseif sScriptFunc == "NC" then
            -- 创建NPC
            local npctype = sArgs
            npctype = tonumber(npctype)
            self:CreateClientNpc(npctype, pid)
            return true
        elseif sScriptFunc == "NMirror" then
            -- 创建镜像NPC
            local npctype = sArgs
            npctype = tonumber(npctype)
            self:CreateClientMirrorNpc(npctype, pid, npcobj)
            return true
        elseif sScriptFunc == "CF" then
            -- 配置跟随npc
            local npctype, sConfigs = table.unpack(split_string(sArgs, ":"))
            npctype = tonumber(npctype)
            sConfigs = string.sub(sConfigs, 2, -2)
            local lConfigs = split_string(sConfigs, "|")
            if #lConfigs then
                local mConfig = ParseSetting(lConfigs)
                self:ConfigFollowNpc(npctype, mConfig)
            end
        elseif sScriptFunc == "SHOP" then
            local npctype = tonumber(sArgs)
            if npctype then
                self:SetShopNpc(npctype)
            end
            return true
        elseif sScriptFunc == "EC" then
            local iEvent = tonumber(sArgs)
            if npcobj and iEvent then
                local npctype = npcobj:Type()
                if npctype then
                    self:SetEvent(npctype,iEvent)
                end
            end
        elseif sScriptFunc == "E" then
            -- 设置事件
            local npctype,iEvent = string.match(sArgs,"(.+):(.+)")
            npctype = tonumber(npctype)
            iEvent = tonumber(iEvent)
            self:SetEvent(npctype,iEvent)
            return true
        elseif sScriptFunc == "SchoolE" then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                local iNpcType = oPlayer:GetSchoolTeacher()
                local iEvent = tonumber(sArgs)
                self:SetEvent(iNpcType,iEvent)
            end
            return true
        elseif sScriptFunc == "ITEM" or sScriptFunc == "I" then
            -- 设置需要物品
            local itemGroupId,iAmount = string.match(sArgs,"(.+):(.+)")
            itemGroupId = tonumber(itemGroupId)
            iAmount = tonumber(iAmount)
            self:SetNeedItem(itemGroupId,iAmount)
            return true
        elseif sScriptFunc == "ITEMG" then
            local sItemGroupIds,iAmount = string.match(sArgs,"(.+):(.+)")
            local lItemGroupIds = split_string(sItemGroupIds, '|', tonumber)
            iAmount = tonumber(iAmount)
            self:SetNeedItemGroup(lItemGroupIds, iAmount)
            return true
        elseif sScriptFunc == "TAKEITEM" then
            -- 自动交付需要物品
            self:TakeNeedItem(pid,npcobj)
            return true
        elseif sScriptFunc == "POPITEM" then
            -- 弹出物品交付UI
            self:PopTakeItemUI(pid,npcobj)
            return true
        elseif sScriptFunc == "SUMM" then
            -- 设置需要宠物
            local iSummGroupId = tonumber(sArgs)
            self:SetNeedSummonFromGroup(pid, iSummGroupId)
            return true
        elseif sScriptFunc == "POPSUMM" then
            -- 弹出宠物交付UI
            self:PopTakeSummonUI(pid, npcobj)
            return true
        elseif sScriptFunc == "SUMMFP" then
            local iNum = tonumber(sArgs)
            self:JudgeSummFreePos(pid, npcobj, iNum)
        elseif sScriptFunc == "TARGET" then
            -- 设置行动目标
            local iTarget = sArgs
            iTarget = tonumber(iTarget)
            self:SetTarget(iTarget)
            return true
        elseif sScriptFunc == "DI" then
            -- 进行对话
            local iDialog = sArgs
            iDialog = tonumber(iDialog)
            self:Dialog(pid,npcobj,iDialog, mArgs)
            return true
        elseif sScriptFunc == "D" then
            -- 角色说话
            local mArgs = split_string(sArgs,":", tonumber)
            local iText, iMenuType = table.unpack(mArgs)
            if not iText then
                return true
            end
            local sText, mMenuArgs = self:GetTextData(iText)
            if sText then
                self:SayText(pid,npcobj,sText, mArgs, mMenuArgs, iMenuType)
            end
            return true
        elseif sScriptFunc == "MSG" then
            local sType, sMsg = table.unpack(split_string(sArgs, "|"))
            self:NotifyMsg(pid, npcobj, sType, sMsg)
        elseif sScriptFunc == "RE" then
            self:RemoveClientNpcEvent(npcobj)
            return true
        elseif sScriptFunc == "RN" then
            -- 回收npc
            self:RemoveClientNpc(npcobj)
            return true
        elseif sScriptFunc == "ANLEI" then
            -- 设置暗雷
            local sArgs = string.sub(sArgs, 2, -2)
            local mArgs = split_string(sArgs,":")
            local sMap,sEvent,sCnt,sMonster = table.unpack(mArgs)
            local lMap = split_string(sMap,"|")
            local iMap = tonumber(lMap[random(#lMap)])
            if iMap then
                iMap = math.floor(iMap)
            end
            local iEvent = tonumber(sEvent)
            if iEvent then
                iEvent = math.floor(iEvent)
            end
            local iNeedCnt = tonumber(sCnt)
            if iNeedCnt then
                iNeedCnt = math.floor(iNeedCnt)
            end
            local iMonsterIdx = tonumber(sMonster)
            if iMonsterIdx then
                iMonsterIdx = math.floor(sMonster)
            end
            self:SetAnlei(iMap,iEvent,iNeedCnt, iMonsterIdx)
            return true
        elseif sScriptFunc == "PICK" then
            -- 设置采集
            local mPArgs = split_string(sArgs,":")
            local iMapId,iPickId,iNeedCnt,sPos = table.unpack(mPArgs)
            local lPos = {}
            if sPos then
                local mPos = split_string(sPos,";")
                for _,sDir in pairs(mPos) do
                    local mDir = split_string(sDir,"|")
                    table.insert(lPos,mDir)
                end
            end
            iMapId = tonumber(iMapId)
            if iMapId then
                iMapId = math.floor(iMapId)
            end
            iPickId = tonumber(iPickId)
            if iPickId then
                iPickId = math.floor(iPickId)
            end
            iNeedCnt = tonumber(iNeedCnt)
            if iNeedCnt then
                iNeedCnt = math.floor(iNeedCnt)
            end
            self:SetPick(iMapId,iPickId,iNeedCnt,lPos)
            return true
        elseif sScriptFunc == "ULCK" then
            -- 解锁
            local iTag = tonumber(sArgs)
            self:UnlockTag(iTag)
            return true
        elseif sScriptFunc == "LINKDONE" then
            self:LinkDone(pid)
            return true
        elseif sScriptFunc == "QTEAM" then
            local iAutoTargetId = tonumber(sArgs)
            self:QuickTeamup(pid, iAutoTargetId)
            return true
        elseif sScriptFunc == "ORGHELP" then
            self:CallOrgHelp(pid)
            return true
        elseif sScriptFunc == "BIAN" then
            local iBianshenId, iSec = table.unpack(split_string(sArgs, ":", tonumber))
            self:BianShen(pid, iBianshenId, iSec)
            return true
        elseif sScriptFunc == "MAIL" then
            local iMailId, iRewardId = table.unpack(split_string(sArgs, ":", tonumber))
            self:SendRewardMail(pid, iMailId, iRewardId, mArgs)
            return true
        elseif sScriptFunc == "NV" then
            local sVisible, sNpcTypes = table.unpack(split_string(sArgs, ":"))
            local bVisible = sVisible == "1"
            local lNpcTypes = split_string(sNpcTypes, "|", tonumber)
            self:SetNpcVisible(pid, lNpcTypes, bVisible)
            return true
        elseif sScriptFunc == "SEFFV" then
            local sVisible, sSEffIds = table.unpack(split_string(sArgs, ":"))
            local bVisible = sVisible == "1"
            local lSEffIds = split_string(sSEffIds, "|", tonumber)
            self:SetSceneEffectVisible(pid, lSEffIds, bVisible)
            return true
        elseif sScriptFunc == "GE" then
            local iOpen = tonumber(sArgs)
            self:SetGhostEye(pid, iOpen)
            return true
        elseif sScriptFunc == "ANIME" then
            local iAnimeId = tonumber(sArgs)
            self:PlayStoryAnime(pid, iAnimeId)
            return true
        elseif sScriptFunc == "ANIMFIGHT" then
            -- local iAnimeId, iAnswer = table.unpack(split_string(sArgs, ":", tonumber))
            local iAnimeId = tonumber(sArgs)
            self:PlayStoryAnimeFight(pid, iAnimeId, npcobj)
            return true
        elseif sScriptFunc == "QTE" then
            local iQteId = tonumber(sArgs)
            self:DoQte(pid, npcobj, iQteId)
            return true
        elseif sScriptFunc == "SETQTE" then
            local mPArgs = split_string(sArgs,":", tonumber)
            local iQteId, iForthDone, iMap, iX, iY = table.unpack(mPArgs)
            self:SetQte(pid, iQteId, iForthDone == 1, iMap, iX, iY)
            return true
        elseif sScriptFunc == "MYGN" then
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oPlayer then
                return true
            end
            local sGlobalNpcType, sFigureId, sGlobalDiaId, sTitle = table.unpack(split_string(sArgs, ":"))
            local iGlobalNpcType = tonumber(sGlobalNpcType)
            if not iGlobalNpcType then
                return true
            end
            local iFigureId = tonumber(sFigureId)
            local iGlobalDiaId = tonumber(sGlobalDiaId)
            self:SetMyGlobalNpc(oPlayer, iGlobalNpcType, iFigureId, iGlobalDiaId, sTitle)
        elseif sScriptFunc == "TASKSAY" then
            local mPArgs = split_string(sArgs,":", tonumber)
            local mSayInfo = {}
            mSayInfo["type"] = mPArgs[1]
            mSayInfo["mapid"] = mPArgs[2]
            mSayInfo["x"] = mPArgs[3]
            mSayInfo["y"] = mPArgs[4]
            self:SetData("sayinfo",mSayInfo)
        elseif sScriptFunc == "SETBHV" then
            local mPArgs = split_string(sArgs, ":")
            local sBehaviors, sCnt = table.unpack(mPArgs)
            local lBehaviors = split_string(sBehaviors, "|", tonumber)
            self:SetBehaviors(pid, lBehaviors, tonumber(sCnt))
            return true
        end
    end
    if self:OtherScript(pid,npcobj,s,mArgs) then
        return true
    end
    return super(CTask).DoScript2(self,pid,npcobj,s,mArgs)
end

function CTask:SetMyGlobalNpc(oPlayer, iGlobalNpcType, iFigureId, iGlobalDiaId, sTitle)
    if sTitle == "" then
        sTitle = nil
    elseif sTitle == "-" then
        sTitle = ""
    end
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SetMyGlobalNpc(iGlobalNpcType, iFigureId, iGlobalDiaId, sTitle)
    oPlayer.m_oActiveCtrl.m_oVisualMgr:SyncMyGlobalNpc(oPlayer, iGlobalNpcType)
end

function CTask:GetQteData(iQteId)
    return table_get_depth(res, {"daobiao", "qte", iQteId})
end

function CTask:HasQteStep()
    return #self.m_lPosQte > 0
end

function CTask:RunQteStep(pid)
    local mQteData = self.m_lPosQte[1]
    if not mQteData then
        self:MissionDone()
        return
    end
    local iQteId, iMap, iX, iY = mQteData.qteid, mQteData.map, mQteData.x, mQteData.y
    local bForthDone = mQteData.forthdone
    local iTaskid = self:GetId()
    local func = function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTaskid, true)
        if oTask then
            oTask:OnQteFindPathCallback(oPlayer, iQteId, bForthDone, mData)
        end
    end
    local mNet = {map_id = iMap, pos_x = iX, pos_y = iY, autotype = self:AutoType()}
    global.oCbMgr:SetCallBack(pid, "AutoFindPath", mNet, nil, func)
end

function CTask:OnQteFindPathCallback(oPlayer, iQteId, bForthDone, mData)
    local pid = oPlayer:GetPid()
    self:SetData("doing_qte", iQteId)
    local taskid = self:GetId()
    local mQteData = self:GetQteData(iQteId)
    local fCallBack = function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if oTask then
            oTask:OnStepQteResCallback(oPlayer, iQteId, mData)
        end
    end
    local mNet = {
        qteid = iQteId,
        forthdone = bForthDone and 1 or 0,
    }
    global.oCbMgr:SetCallBack(pid, "GS2CPlayQte", mNet, nil, fCallBack)
end

function CTask:OnStepQteResCallback(oPlayer, iQteId, mData)
    local iDoingQteId = self:GetData("doing_qte")
    if iDoingQteId then
        self:SetData("doing_qte", nil)
        if iDoingQteId ~= iQteId then
            return
        end
    end
    local iAnswer = mData.answer
    local bDone, bClear = self:StepQte(iDoingQteId, iAnswer)
    if bClear then
        local npctype = self:Target()
        if not npctype then
            self:MissionDone()
        else
            self:MissionReach()
        end
    end
end

function CTask:DoQte(pid, npcobj, iQteId)
    local taskid = self:GetId()
    local mQteData = self:GetQteData(iQteId)
    assert(mQteData, string.format("task do qteid no data, taskid:%d, qteId:%s", taskid, iQteId))
    local npcid = 0
    if npcobj then
        npcid = npcobj:ID()
    end
    local fCallBack = function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if oTask then
            oTask:OnQteCallback(oPlayer, npcid, iQteId, mData)
        end
    end
    local mNet = {
        qteid = iQteId,
    }
    global.oCbMgr:SetCallBack(pid, "GS2CPlayQte", mNet, nil, fCallBack)
end

function CTask:OnQteCallback(oPlayer, npcid, iQteId, mData)
    local iEvent
    iEvent = self:GetEvent(npcid)
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end

    local iAnswer = mData.answer
    local mAnswer = mEvent.answer
    local s = mAnswer[iAnswer]
    if not s then
        return
    end
    local pid = oPlayer:GetPid()
    local oNpc = self:GetNpcObj(npcid)
    self:DoScriptCallbackUnit(pid, oNpc, s, mArgs or {})
end

function CTask:SetQte(pid, iQteId, bForthDone, iMap, iX, iY)
    if iMap < 100000 then
        local lMaplist = self:GetSceneGroup(iMap)
        iMap = lMaplist[random(#lMaplist)]
    end
    if not iX or not iY then
        iX, iY = global.oSceneMgr:RandomPos2(iMap)
    end
    local mData = {
        qteid = iQteId,
        forthdone = bForthDone,
        map = iMap,
        x = iX,
        y = iY,
    }
    table.insert(self.m_lPosQte, mData)
    self:Dirty()
end

function CTask:OtherScript(pid,npcobj,s,mArgs)
end

function CTask:GiveSummon(pid,sumid,attrid)
end

function CTask:GivePartner(pid,parid)
end

function CTask:InitWarInfo(mData)
    local mWarInfo = super(CTask).InitWarInfo(self, mData)
    mWarInfo.source = {type = "task", id = self:GetId()}
    return mWarInfo
end

function CTask:GetWarConfig()
    if self:IsAnlei() then
        local mData = self:GetData("anlei",{})
        local mMonster = {}
        for iMap, mAnlei in pairs(mData) do
            local iEvent,iDoneCnt,iNeedCnt,iMonsterIdx = table.unpack(mAnlei)
            if iMonsterIdx then
                mMonster[iMonsterIdx] = true
            end
        end
        if next(mMonster) then
            return {record_add_npc = mMonster}
        end
    end
    return nil
end

function CTask:HasWarAssertMsg(pid, iFight)
    return "taskid:" .. self:GetId()
end

function CTask:RewardInfo()
    local mData = self:GetTaskData()
    return mData["submitRewardStr"]
end

function CTask:InitLinkId(iLinkId)
    if not self:GetLinkId() then
        self:SetLinkId(iLinkId)
    end
end

function CTask:ValidTakeItemGroup(oPlayer, npcobj)
    if not oPlayer then
        return false
    end
    for groupid,iAmount in pairs(self.m_mNeedItemGroup) do
        local lItemGroup = global.oItemLoader:GetItemGroup(groupid)
        local iHasAmount = 0
        for _, sid in ipairs(lItemGroup) do
            iHasAmount = iHasAmount + self:CountSubmitableItems(oPlayer, sid)
            if iHasAmount >= iAmount then
                break
            end
        end
        if iHasAmount < iAmount then
            return false, groupid
        end
    end
    return true
end

function CTask:IsItemSubmitable(oPlayer, oItem)
    return oItem:ValidSubmit()
end

function CTask:CountSubmitableItems(oPlayer, iItemSid)
    local oItemCtrl = oPlayer.m_oItemCtrl
    local iCnt = 0
    for _, oItem in ipairs(oItemCtrl:GetShapeItem(iItemSid)) do
        if self:IsItemSubmitable(oPlayer, oItem) then
            iCnt = iCnt + oItem:GetAmount()
        end
    end
    return iCnt
end

function CTask:ValidTakeItem(pid,npcobj)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end
    for sid,iAmount in pairs(self.m_mNeedItem) do
        if self:CountSubmitableItems(oPlayer, sid) < iAmount then
            return false, sid
        end
    end

    local bPass, iLackId = self:ValidTakeItemGroup(oPlayer, npcobj)
    if not bPass then
        return false, iLackId
    end

    return true
end

-- 自动交付物品
-- PS：自动提交是不能用于星级物品奖励加成的
-- PS: 有定制限制条件的不能用自动扣除（未检查）
function CTask:TakeNeedItem(pid,npcobj)
    -- 物品按分类交付是不能自动扣的
    if next(self.m_mNeedItemGroup) then
        return
    end
    if not self:ValidTakeItem(pid,npcobj) then
        return
    end
    if not npcobj then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    for _, sid in ipairs(table_key_list(self.m_mNeedItem)) do
        local iAmount = self.m_mNeedItem[sid]
        if not oPlayer:RemoveItemAmount(sid,iAmount,string.format("交付任务%s[%d]",self:GetDirName(),self:GetId())) then
            -- TODO 记录调整，保证交付不会丢失，记录以经交付数量并拥有作为计数下行
            return
        end
        self.m_mNeedItem[sid] = nil
        self:Dirty()
    end
    local iEvent = self:GetEvent(npcobj.m_ID)
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end
    self:DoScript(pid,npcobj,mEvent["win"])
end

function CTask:CheckPopedItemsEnough(oPlayer, mAmount)
    local oNotifyMgr = global.oNotifyMgr
    for sid, iAmount in pairs(self.m_mNeedItem) do
        local iLeftAmount = (mAmount[sid] or 0) - iAmount
        if iLeftAmount < 0 then
            oNotifyMgr:Notify(oPlayer.m_iPid, global.oItemLoader:GetItemNameBySid(sid) .. "不足")
            return false
        elseif iLeftAmount == 0 then
            mAmount[sid] = nil
        else
            mAmount[sid] = iLeftAmount
        end
    end

    for groupid, iNeedAmount in pairs(self.m_mNeedItemGroup) do
        local lItemGroup = global.oItemLoader:GetItemGroup(groupid)
        for sid, iHasAmount in pairs(mAmount) do
            if extend.Table.find(lItemGroup, sid) then
                if iNeedAmount == iHasAmount then
                    mAmount[sid] = nil
                    iNeedAmount = 0
                    break
                elseif iNeedAmount > iHasAmount then
                    mAmount[sid] = nil
                    iNeedAmount = iNeedAmount - iHasAmount
                else -- iNeedAmount < iHasAmount
                    mAmount[sid] = iHasAmount - iNeedAmount
                    iNeedAmount = 0
                    break
                end
            end
        end
        if iNeedAmount > 0 then
            oNotifyMgr:Notify(oPlayer:GetPid(), global.oItemLoader:GetItemGroupName(groupid) .. "不足")
            return false
        end
    end

    for sid, iLeftAmount in pairs(mAmount) do
        local sItemName = global.oItemLoader:GetItemNameBySid(sid)
        global.oNotifyMgr:Notify(oPlayer.m_iPid, sItemName .. "多余")
        return false
    end
    return true
end

function CTask:DoSubmitItem(oPlayer, mData)
    local mItemList = mData["itemlist"]
    local mAmount = {}
    local iLeastStar
    for _,mInfo in pairs(mItemList) do
        local iItemid = mInfo["id"]
        local iAmount = mInfo["amount"]
        if iAmount > 0 then
            local oItem = oPlayer.m_oItemCtrl:HasItem(iItemid)
            if not oItem or oItem:GetAmount() < iAmount then
                oPlayer:NotifyMessage("身上没有此道具")
                return
            end
            if not self:IsItemSubmitable(oPlayer, oItem) then
                if oItem:IsLocked() then
                    local sMsg = self:GetTextData(1105)
                    sMsg = global.oToolMgr:FormatColorString(sMsg, {item = oItem:Name()})
                    oPlayer:NotifyMessage(sMsg)
                else
                    oPlayer:NotifyMessage("此道具不可交付")
                end
                return
            end
            local iStar = oItem:Quality()
            if not iLeastStar or iLeastStar > iStar then
                iLeastStar = iStar
            end
            local iSid = oItem:SID()
            if not mAmount[iSid] then
                mAmount[iSid] = 0
            end
            mAmount[iSid] = mAmount[iSid] + iAmount
        end
    end

    if not self:CheckPopedItemsEnough(oPlayer, mAmount) then
        return
    end

    -- local sReason = string.format("提交[%d]%s任务", self:GetId(), self:Name())
    local sReason = string.format("交付任务%s[%d]",self:GetDirName(),self:GetId())
    for _,mInfo in pairs(mItemList) do
        local iItemid = mInfo["id"]
        local iAmount = mInfo["amount"]
        if iAmount > 0 then
            local oItem = oPlayer.m_oItemCtrl:HasItem(iItemid)
            if not oItem or oItem:GetAmount() < iAmount then
                return
            end
            if not self:IsItemSubmitable(oPlayer, oItem) then
                return
            end
            -- FIXME 加记录已经扣除的内容
            oPlayer:RemoveOneItemAmount(oItem, iAmount, sReason)
        end
    end
    -- 高级寻物专用星级属性，马上就交付任务了，不存盘
    self.m_tmp_iSubmitItemStar = iLeastStar
    return true
end

function CTask:OnTakeItemUICallback(oPlayer, npcid, mData)
    if not self:DoSubmitItem(oPlayer, mData) then
        return
    end
    local npcobj = self:GetNpcObj(npcid)
    self:MissionDone(npcobj)
end

function CTask:PopTakeItemUI(pid,npcobj)
    if not self:ValidTakeItem(pid,npcobj) then
        return
    end
    local mData = {}
    local taskid = self.m_ID
    local npcid
    if npcobj then
        npcid = npcobj:ID()
    end
    mData["taskid"]  = taskid

    local cbFunc = function (oPlayer,mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if not oTask then
            return
        end
        oTask:OnTakeItemUICallback(oPlayer, npcid, mData)
    end

    local oCbMgr = global.oCbMgr
    oCbMgr:SetCallBack(pid,"GS2CPopTaskItem",mData,nil,cbFunc)
end

function CTask:SendAnyoneTaskNeeds(oAnyone)
    local iTaskId = self:GetId()
    local mNet = {
        taskid = iTaskId,
        owner = self:GetOwner(),
        tasktype = self:TaskType(),
        needitem = self:PackNeedItem(),
        needitemgroup = self:PackNeedItemGroup(),
        ext_apply_info = self:PackExtApplyInfo(),
    }
    oAnyone:Send("GS2CTargetTaskNeeds", mNet)
end

function CTask:IsSummonSubmitable(oPlayer, oSummon)
    return oPlayer.m_oSummonCtrl:IsSummonSubmitable(oSummon)
end

function CTask:CountSubmitableSummons(oPlayer, iSummSid)
    local oSummCtrl = oPlayer.m_oSummonCtrl
    local iCnt = 0
    for summid, oSummon in pairs(oSummCtrl:SummonList()) do
        if iSummSid == oSummon:TypeID() then
            if self:IsSummonSubmitable(oPlayer, oSummon) then
                iCnt = iCnt + 1
            end
        end
    end
    return iCnt
end

function CTask:ValidTakeSummon(pid, npcobj)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end
    for sid, iAmount in pairs(self.m_mNeedSummon) do
        if self:CountSubmitableSummons(oPlayer, sid) < iAmount then
            return false
        end
    end
    return true
end

function CTask:OnTakeSummonUICallback(oPlayer, npcid, mData)
    local lSummonIds = mData.summonlist
    local mAmount = {}
    local mSummons = {}
    local oSummCtrl = oPlayer.m_oSummonCtrl
    for _, summid in ipairs(lSummonIds) do
        local oSummon = oSummCtrl:GetSummon(summid)
        if oSummon then
            local sid = oSummon:TypeID()
            if not self.m_mNeedSummon[sid] then
                global.oNotifyMgr:Notify(oPlayer.m_iPid, "不需要多余的" .. oSummon:Name())
                return
            end
            mAmount[sid] = (mAmount[sid] or 0) + 1
            mSummons[summid] = oSummon
        else
            -- record.warning("TakeSummonUI send proto hasn't summid:%d, pid:%d, taskid:%d", summid, oPlayer:GetPid(), self:GetId())
            oPlayer:NotifyMessage("你没有此宠物")
            return
        end
    end
    for sid, iAmount in pairs(self.m_mNeedSummon) do
        if iAmount ~= (mAmount[sid] or 0) then
            global.oNotifyMgr:Notify(oPlayer.m_iPid, "数量不匹配")
            return
        end
    end
    for summid, oSummon in pairs(mSummons) do
        if not self:IsSummonSubmitable(oPlayer, oSummon) then
            global.oNotifyMgr:Notify(oPlayer.m_iPid, "不可提交")
            return
        end
    end
    local sReason = string.format("交付任务%s[%d]",self:GetDirName(),self:GetId())
    for summid, oSummon in pairs(mSummons) do
        oSummCtrl:RemoveSummon(oSummon, sReason, {recevery=true})
    end
    local oNpc = self:GetNpcObj(npcid)
    self:MissionDone(oNpc)
end

function CTask:PopTakeSummonUI(pid, npcobj)
    if not self:ValidTakeSummon(pid, npcobj) then
        return
    end

    local taskid = self.m_ID
    local npcid = npcobj:ID()

    local fDealCb = function(oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if not oTask then
            return
        end
        oTask:OnTakeSummonUICallback(oPlayer, npcid, mData)
    end

    local mNet = {taskid = taskid}
    local oCbMgr = global.oCbMgr
    oCbMgr:SetCallBack(pid,"GS2CPopTaskSummon", mNet, nil, fDealCb)
end

function CTask:JudgeSummFreePos(pid, npcobj, iNum)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local iEvent = self:GetEvent(npcobj:ID())
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end
    local bSucc
    if iNum <= 0 then
        bSucc = true
    else
        bSucc = (iNum <= oPlayer.m_oSummonCtrl:EmptySpaceCnt())
    end
    if bSucc then
        self:DoScript(pid, npcobj, mEvent["win"], mArgs)
    else
        self:DoScript(pid, npcobj, mEvent["fail"], mArgs)
    end
end

function CTask:IsAnlei()
    if self:TaskType() ~= gamedefines.TASK_TYPE.TASK_ANLEI then
        return false
    end
    local mData = self:GetData("anlei",{})
    if not next(mData) then
        return false
    end
    return true
end

function CTask:IsNeedLoginAnleiXunluo()
    return false
end

-- function CTask:ActiveAnlei()
--     local pid = self.m_Owner
--     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
--     self.m_oAnLeiCtrl:Add(pid, oPlayer:GetNowPos())
-- end

function CTask:SetAnlei(iMap,iEvent,iNeedCnt, iMonsterIdx)
    assert(iNeedCnt > 0, string.format("SetAnlei cnt err, taskid=%d", self.m_ID))
    local mData = self:GetData("anlei",{})
    if mData[iMap] then
        return
    end
    self:Dirty()
    -- iEvent, iDoneCnt, iNeedCnt, iNeedMonsterIdx
    mData[iMap] = {iEvent, 0, iNeedCnt, iMonsterIdx}
    self:SetData("anlei",mData)
    -- 不能立即激活暗雷，需要玩家移动时Update激活
    -- self:ActiveAnlei()
    self:RegAnlei()
end

function CTask:RegAnleiForOne(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    local iTaskId = self:GetId()
    local mData = self:GetData("anlei",{})
    for iMap, _ in pairs(mData) do
        oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:RegTaskMap(iTaskId, iMap)
    end
end

function CTask:OnStopXunLuo(oPlayer)
end

function CTask:RegAnlei()
    local mOwners
    if self:IsTeamTask() then
        mOwners = self:GetOwners()
    else
        mOwners = {[self:GetOwner()] = 1}
    end
    for pid, _ in pairs(mOwners) do
        self:RegAnleiForOne(pid)
    end
end

function CTask:UnRegAnleiForOne(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end
    local iTaskId = self:GetId()
    oPlayer.m_oTaskCtrl.m_oAnLeiCtrl:UnregWholeTask(iTaskId)
end

function CTask:UnRegAnlei()
    local mOwners
    if self:IsTeamTask() then
        mOwners = self:GetOwners()
    else
        mOwners = {[self:GetOwner()] = 1}
    end
    for pid, _ in pairs(mOwners) do
        self:UnRegAnleiForOne(pid)
    end
end

function CTask:TouchAnleiCtrl()
    if self:IsAnlei() then
        self:RegAnlei()
    end
end

-- function CTask:ValidTriggerAnlei(iMap)
--     local mData = self:GetData("anlei",{})
--     if not mData[iMap] then
--         return false
--     end
--     return true
-- end

--触发暗雷
function CTask:TriggerAnLei(iMap)
    local mData = self:GetData("anlei",{})
    local mAnlei = mData[iMap] or {}
    if not mAnlei then
        return
    end
    local iEvent,iDoneCnt,iNeedCnt,iMonsterIdx = table.unpack(mAnlei)
    if iDoneCnt >= iNeedCnt then
        self:MissionDone()
        return
    end
    local pid = self.m_Owner
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end
    self:DoScript(pid,nil,mEvent["look"])
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        oNowWar.m_iEvent = iEvent
    end
end

function CTask:TouchAnLeiDone(pid, npcobj, mWarCbArgs)
    if not self:IsAnlei() then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    local iMap = oNowScene:MapId()

    local mData = self:GetData("anlei",{})
    local mAnleiData = mData[iMap]
    if not mAnleiData then
        return
    end
    local iEvent, iDoneCnt,iNeedCnt, iMonsterIdx = table.unpack(mAnleiData)
    local mEvent = self:GetEventData(iEvent)
    assert(mEvent, string.format("anlei event err, taskid=%d, event=%d", self.m_ID, iEvent))

    local iDoneCntNew
    if iMonsterIdx then
        local iMonsterCnt = table_get_depth(mWarCbArgs, {"warresult", "monster_info", "monster_cnt", gamedefines.WAR_WARRIOR_SIDE.ENEMY, iMonsterIdx})
        if iMonsterCnt then
            iDoneCntNew = iDoneCnt + iMonsterCnt
        end
    elseif iEvent then
        iDoneCntNew = iDoneCnt + 1
    end

    if iDoneCntNew then
        if iDoneCntNew < iNeedCnt then
            mData[iMap] = {iEvent, iDoneCntNew, iNeedCnt, iMonsterIdx}
            self:SetData("anlei",mData)
            self:Refresh()
        else
            -- 此处设定表示仅一个场景的暗雷事件
            self:MissionDone(npcobj)
            oPlayer:Send("GS2CXunLuo",{type=0})
            return
        end
    end

    self:DoScript(pid, npcobj, mEvent["win"])
end

function CTask:IsAnleiWarWinTouchMissionDone()
    return true
end

function CTask:CheckFighersOwnTask(oWar, pid, npcobj, mWarCbArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local iOwner = self:GetOwner()
    local lFighters = self:GetFighterList(oPlayer, mWarCbArgs)
    if extend.Array.find(lFighters, iOwner) then
        return true
    end
    return false
end

-- 组队中Fighters各自任务的共同完成touch
function CTask:TouchWarWinMissionDone(oWar, pid, npcobj, mWarCbArgs)
    if not self:CheckFighersOwnTask(oWar, pid, npcobj, mWarCbArgs) then
        return
    end
    local iType = self:TaskType()
    if self:IsAnlei() and self:IsAnleiWarWinTouchMissionDone() then
        self:TouchAnLeiDone(pid, npcobj, mWarCbArgs)
    elseif iType == gamedefines.TASK_TYPE.TASK_NPC_FIGHT then
        super(CTask).OnWarWin(self, oWar, pid, npcobj, mWarCbArgs)
    else
        super(CTask).OnWarWin(self, oWar, pid, npcobj, mWarCbArgs)
    end
end

-- @Overrideable
-- 任务的OnWarWin实际到每个人的执行接口，IsWarTeamMembersShareDone时，队员若有任务一同完成，该接口也会调用
function CTask:OnDealMemberSameTaskWarWin(oWar, pid, npcobj, mWarCbArgs)
    self:TouchWarWinMissionDone(oWar, pid, npcobj, mWarCbArgs)
end

-- @Override-with-super-do
-- 重写该方法需保持super内部的OnTryTeamWarWin逻辑执行
function CTask:OnWarWin(oWar, pid, npcobj, mWarCbArgs)
    self:DealBeforeOnWarWin(oWar, pid, npcobj, mWarCbArgs)
    if self:IsWarTeamMembersShareDone(oWar, pid, npcobj, mWarCbArgs) then
        -- 遍历任务的队员，都进行OnDealMemberSameTaskWarWin操作
        global.oTaskMgr:OnTryTeamWarWin(self, oWar, pid, npcobj, mWarCbArgs)
    else
        self:OnDealMemberSameTaskWarWin(oWar, pid, npcobj, mWarCbArgs)
    end
    self:DealAfterOnWarWin(oWar, pid, npcobj, mWarCbArgs)
end

-- @Overrideable
-- 组队做任务是否一同完成各自此任务
function CTask:IsWarTeamMembersShareDone(oWar, iPid, npcobj, mWarCbArgs)
    return false
end

-- @Overrideable
function CTask:DealBeforeOnWarWin(oWar, pid, npcobj, mWarCbArgs)
end

-- @Overrideable
function CTask:DealAfterOnWarWin(oWar, pid, npcobj, mWarCbArgs)
end

local CONDI_VALID = {
    VALID = 1,
    NULL = 0,
    INVALID = -1,
}
function CTask:TouchCondiReachMission()
    local iRes = self:ValidTaskConditions()
    if iRes == CONDI_VALID.INVALID then
        self:MissionUnReach()
        return
    end
    local bDone = self:MissionReach()
    return bDone
end

function CTask:CheckGrade(iGrade)
    local iRes = self:ValidTaskConditions()
    if iRes == CONDI_VALID.NULL then
        return
    end
    if iRes == CONDI_VALID.INVALID then
        self:MissionUnReach()
        return
    end
    self:MissionReach()
end

function CTask:ValidTaskConditions()
    -- if self:IsForbidSubmit() then
    --     return CONDI_VALID.INVALID
    -- end
    local mCondi = self:GetData("conditions")
    if not mCondi then
        return CONDI_VALID.NULL
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    for sKey, iCondi in pairs(mCondi) do
        if sKey == "grade" then
            if oPlayer:GetGrade() < iCondi then
                return CONDI_VALID.INVALID
            end
        end
    end
    return CONDI_VALID.VALID
end

function CTask:SetShopNpc(npctype)
    self:SetData("shop_npc", npctype)
end

function CTask:GetShopNpc()
    return self:GetData("shop_npc", gamedefines.NPC_TYPE.SHOP)
end

function CTask:GetNeedItemShopNpc()
    local npctype = self:GetData("shop_npc")
    if npctype then
        return npctype
    end
    local iItemSid = next(self.m_mNeedItem)
    if not iItemSid then
        local iGroup = next(self.m_mNeedItemGroup)
        if iGroup then
            local lGroupItems = global.oItemLoader:GetItemGroup(groupid)
            iItemSid = next(lGroupItems or {})
        end
    end
    if iItemSid then
        local mItemData = global.oItemLoader:GetItemData(iItemSid)
        local iShopNpcType = mItemData.shop_npctype
        if iShopNpcType and iShopNpcType > 0 then
            return iShopNpcType
        end
    end
    return gamedefines.NPC_TYPE.SHOP
end

function CTask:AbleTeamMemberClick(pid)
end

function CTask:AbleInWarClick(pid)
end

-- @return: bBreak, npctype
function CTask:OnClickTaskFindSummon(oPlayer)
    local iPid = oPlayer:GetPid()
    local npctype
    if not self:ValidTakeSummon(iPid) then
        -- 出售商店npc
        npctype = self:GetShopNpc()
    else
        npctype = self:Target()
    end
    return false, npctype
end

--点击任务
function CTask:Click(pid)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if self:IsForbidSubmit() then
        oPlayer:NotifyMessage(self:GetTextData(2002))
        return
    end
    self:TrueDoClick(oPlayer)
end

function CTask:TrueDoClick(oPlayer)
    local pid = oPlayer:GetPid()
    local oNotifyMgr = global.oNotifyMgr
    local npctype
    local bBreak
    local iType = self:TaskType()
    if gamedefines.TASK_TYPE.TASK_FIND_ITEM == iType then
        if not self:ValidTakeItem(pid) then
            -- 出售商店npc
            npctype = self:GetShopNpc()
        else
            npctype = self:Target()
        end
    elseif gamedefines.TASK_TYPE.TASK_FIND_SUMMON == iType then
        if not self:ValidTakeSummon(pid) then
            -- 出售商店npc
            npctype = self:GetShopNpc()
        else
            npctype = self:Target()
        end
        bBreak, npctype = self:OnClickTaskFindSummon(oPlayer)
        if bBreak then
            return
        end
    elseif extend.Table.find({gamedefines.TASK_TYPE.TASK_ANLEI},iType) then
        local mData = self:GetData("anlei",{})
        local iToMap
        for iMap,_ in pairs(mData) do
            local oSceneMgr = global.oSceneMgr
            iMap = tonumber(iMap)
            assert(iMap,string.format("anlei err, owner:%d, taskid:%d",self.m_Owner,self.m_ID))
            iToMap = iMap
        end
        self:RunXunLuo(oPlayer, iToMap)
    elseif gamedefines.TASK_TYPE.TASK_UPGRADE == iType then
        local bMissionDone = self:TouchCondiReachMission(oPlayer:GetGrade())
        if bMissionDone then
            return
        end
        if not self.m_tmp_bReach then
            -- 开日程面板
            -- oNotifyMgr:Notify(oPlayer.m_iPid, self:GetTextData(10002))
            oPlayer:Send("GS2COpenScheduleUI", {})
            return
        else
            npctype = self:Target()
        end
    elseif gamedefines.TASK_TYPE.TASK_SAY == iType then
        self:TaskSay(oPlayer)
    elseif gamedefines.TASK_TYPE.TASK_QTE == iType then
        if self:HasQteStep() then
            self:RunQteStep(pid)
            return
        else
            npctype = self:Target()
            if not npctype then
                self:MissionDone()
                return
            end
        end
    elseif gamedefines.TASK_TYPE.TASK_BEHAVIOR == iType then
        if self:IsBehaviorFullDone() then
            npctype = self:Target()
            if not npctype then
                self:MissionDone()
                return
            else
                --引导任务调整为达成时，点击直接完成
                if self.m_tmp_bReach then
                    self:MissionDone()
                    return
                end
            end
        else
            self:DoBehavior(oPlayer)
        end
    else
        npctype = self:Target()
    end
    if npctype then
        if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
            self:AutoFindNpcPath(pid, npctype)
        end
    end
end

function CTask:RunXunLuo(oPlayer, iMap)
    -- PS. 直接跳场景(暂定AutoType都是1)
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:MapId() ~= iMap then
        if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
            global.oSceneMgr:ChangeMap(oPlayer, iMap)
        end
    end
    oPlayer:Send("GS2CXunLuo",{type=1})
    return
end

function CTask:AutoFindNpcPath(pid, npctype)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oNpc = self:GetNpcObjByType(npctype)
    if not oNpc then
        return
    end
    local iMap = oNpc:MapId()
    local iX = oNpc.m_mPosInfo["x"]
    local iY = oNpc.m_mPosInfo["y"]
    local iAutoType = self:AutoType()
    local oSceneMgr = global.oSceneMgr
    if is_production_env() then
        -- oSceneMgr:SceneAutoFindPath(pid,iMap,iX,iY,oNpc.m_ID,self:AutoType())
        global.oNpcMgr:GotoNpcAutoPath(oPlayer, oNpc, iAutoType)
    else
        -- 定位寻路报错任务用【临时】
        -- local bSucc = safe_call(oSceneMgr.SceneAutoFindPath, oSceneMgr, pid,iMap,iX,iY,oNpc.m_ID,self:AutoType())
        local bSucc = safe_call(global.oNpcMgr.GotoNpcAutoPath, global.oNpcMgr, oPlayer, oNpc, iAutoType)
        if not bSucc then
            assert(nil, string.format("findpath err, pid:%d,npctype:%d,taskid:%d,mapid:%d", pid, npctype, self:GetId(), iMap))
        end
    end
end

function CTask:GetNpcObj(npcid)
    -- npc都在oNpcMgr的管理下，不需要从m_mClientNpc里找
    -- TODO 尽量不要通过oNpcMgr进行两份引用，仍然从m_mClientNpc与m_mFollowNpc中查找（需要同时处理LifeEnd的注册）
    if not npcid then
        return nil
    end
    local oNpcMgr = global.oNpcMgr
    local oNpc = oNpcMgr:GetObject(npcid)
    return oNpc
end

function CTask:GetNpcObjByType(npctype)
    for _,oClientNpc in pairs(self.m_mClientNpc) do
        if oClientNpc:Type() == npctype then
            return oClientNpc
        end
    end
    local oNpcMgr = global.oNpcMgr
    local oGlobalNpc = oNpcMgr:GetGlobalNpc(npctype)
    if oGlobalNpc then
        return oGlobalNpc
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetOwner())
    if oPlayer then
        return oNpcMgr:GetVirtualGlobalNpc(oPlayer, npctype)
    end
end

function CTask:ValidFight(pid,npcobj,iFight)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return false
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        return false
    end
    return true
end

function CTask:IsNpcTaskClientObj(oNpc)
    if table_in_list(self.m_mClientNpc, oNpc) then
        return true
    end
    return false
end

function CTask:SetEvent(npctype,iEvent)
    self:Dirty()
    for _,oClientNpc in pairs(self.m_mClientNpc) do
        if oClientNpc:Type() == npctype then
            oClientNpc:SetEvent(iEvent)
            return
        end
    end
    --npc组
    if npctype < 1000 then
        local npclist = self:GetNpcGroupData(npctype)
        npctype = npclist[random(#npclist)]
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetGlobalNpc(npctype)
        if not oNpc then
            oNpc = self:CreateClientNpc(npctype, self.m_Owner)
            oNpc:SetEvent(iEvent)
            return
        end
    end
    self.m_mEvent[npctype] = iEvent
end

function CTask:GetEvent(npcid)
    local oNpc = self:GetClientObj(npcid)
    local iEvent
    if oNpc then
        iEvent = oNpc:GetEvent()
    else
        local oNpcMgr = global.oNpcMgr
        oNpc = self:GetNpcObj(npcid)
        if not oNpc then
            return
        end
        local npctype = oNpc:Type()
        iEvent = self.m_mEvent[npctype]
    end
    return iEvent
end

function CTask:RemoveClientNpcEvent(oNpc)
    if not oNpc then return end
    if table_in_list(self.m_mClientNpc, oNpc) then
        local iEvent = oNpc:GetEvent()
        if not iEvent then
            return
        end
        oNpc:SetEvent(nil)
        self:Dirty()
    end
    local npctype = oNpc:Type()
    if not self.m_mEvent[npctype] then
        self.m_mEvent[npctype] = nil
        self:Dirty()
    end
    self:Refresh()
end

-- 响应npc事件（可能来自点击）
function CTask:DoNpcEvent(pid, npcid)
    if self:IsForbidSubmit() then
        global.oNotifyMgr:Notify(pid, self:GetTextData(2002))
        return true
    end
    local oNpc = self:GetNpcObj(npcid)
    local iEvent = self:GetEvent(npcid)
    if not iEvent then
        return false
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return false
    end
    if self.m_tmp_bReach then
        self:DoScript(pid,oNpc,mEvent["reach"])
    else
        self:DoScript(pid,oNpc,mEvent["look"])
    end
    return true
end

function CTask:DoParseDialogData(mDialog, pid, npcobj)
    mDialog["content"] = self:TransString(pid,npcobj,mDialog["content"])
    if type(mDialog["preId"]) == "string" then
        mDialog["preId"] = tonumber(self:TransString(pid, npcobj, mDialog["preId"])) or 0
    end
end

function CTask:Dialog(pid,npcobj,iDialog, mArgs)
    local mDialogData = table_deep_copy(self:GetDialogData(iDialog))
    if not mDialogData then
        return
    end
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        return
    end
    for _,mDialog in pairs(mDialogData) do
        self:DoParseDialogData(mDialog, pid, npcobj)
    end
    local mNet = {}
    mNet["dialog"] = mDialogData
    mNet["taskid"] = self:GetId()
    if self.m_tmp_sPlots then
        self:DialogPlot(pid, npcobj, mDialogData)
        return
    end
    if not npcobj then
        self:GS2CDialog(oPlayer,mNet)
        return
    end
    local npcid = npcobj.m_ID
    local iEvent
    if not mArgs or not mArgs.forbidEvent then
        iEvent = self:GetEvent(npcid)
    end
    if not iEvent then
        self:GS2CDialog(oPlayer,mNet)
        return
    end
    self:DialogRespond(pid, npcobj, iEvent, mDialogData)
end

function CTask:GetDialogPlotCbFunc(pid, iTaskId, npcid)
end

function CTask:DialogPlot(pid, npcobj, mDialogData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local taskid = self:GetId()
    local npcid
    local sNpcName
    local mModelInfo
    if npcobj then
        npcid = npcobj:ID()
        sNpcName = npcobj:Name()
        mModelInfo = npcobj:ModelInfo()
    end
    local cbFunc = self:GetDialogPlotCbFunc(pid, taskid, npcid)
    local mNet = {}
    mNet["dialog"] = mDialogData
    mNet["npc_name"] = sName
    mNet["model_info"] = mModelInfo
    mNet["taskid"] = taskid
    self:GS2CDialog(oPlayer, mNet, cbFunc)
end

function CTask:DialogRespond(pid, npcobj, iEvent, mDialogData)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local taskid = self:GetId()
    local npcid = npcobj:ID()
    local cbFunc = function (oPlayer, mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if not oTask then
            return
        end
        oTask:OnConfirmDialog(mData, pid, npcid, iEvent)
    end
    local mNet = {}
    mNet["dialog"] = mDialogData
    mNet["npc_name"] = npcobj:Name()
    mNet["model_info"] = npcobj:ModelInfo()
    mNet["taskid"] = taskid
    self:GS2CDialog(oPlayer, mNet, cbFunc)
end

function CTask:OnConfirmDialog(mData, pid, npcid, iEvent)
    local oNpc = self:GetNpcObj(npcid)
    if not oNpc then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent or not mEvent.answer then
        return
    end
    -- 限制回调应该在DoScript内判断，针对不同玩法不同处理
    self:DoScriptCallbackList(pid, oNpc, mEvent.answer, {})
end

function CTask:NonCharacterSay(oPlayer, sText, mMenuArgs, iMenuType, bIsLv2)
    local mNet = {}
    mNet["text"] = sText
    mNet["type"] = iMenuType
    mNet["lv2"] = bIsLv2 and 1 or nil
    if mMenuArgs then
        for sKey, xValue in pairs(mMenuArgs) do
            mNet[sKey] = xValue
        end
    end
    oPlayer:Send("GS2CNpcSay",mNet)
end

function CTask:SayText(pid,npcobj,sText, mArgs, mMenuArgs, iMenuType)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        return
    end
    if not npcobj then
        self:NonCharacterSay(oPlayer, sText, mMenuArgs, iMenuType, true)
        return
    end
    if self.m_tmp_sPlots then
        npcobj:Say(pid, sText, mMenuArgs, iMenuType, true)
        return
    end

    local npcid = npcobj.m_ID
    local iEvent
    if not mArgs or not mArgs.forbidEvent then
        iEvent = self:GetEvent(npcid)
    end
    if not iEvent then
        npcobj:Say(pid, sText, mMenuArgs, iMenuType, true)
        return
    end
    local mEvent = self:GetEventData(iEvent)
    local mAnswer = mEvent["answer"] or {}
    if table_count(mAnswer) == 0 then
        npcobj:Say(pid, sText, mMenuArgs, iMenuType, true)
        return
    end
    self:SayRespondText(pid,npcobj,sText, mMenuArgs, iMenuType)
end

function CTask:OnSayRespondCanCallback(oPlayer, npcid, mData)
    local pid = oPlayer.m_iPid
    local oTeam = oPlayer:HasTeam()
    if oTeam and not oTeam:IsLeader(pid) and oTeam:IsTeamMember(pid) then
        return false
    end
    local oNpc = self:GetNpcObj(npcid)
    if not oNpc then
        return false
    end
    -- local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    -- if oNowWar then
    --     record.warning("OnSayRespondCanCallback when in war, pid:%d,npcid:%d,taskid:%d", pid, npcid, self:GetId())
    --     return false
    -- end
    return true
end

function CTask:OnSayRespondCallback(oPlayer, npcid, mData)
    local iEvent
    if not mArgs or not mArgs.forbidEvent then
        iEvent = self:GetEvent(npcid)
    end
    if not iEvent then
        return
    end
    local mEvent = self:GetEventData(iEvent)
    if not mEvent then
        return
    end
    local iAnswer = mData["answer"]
    -- self:SetOptionAnswer(iAnswer)
    local mAnswer = mEvent["answer"]
    local s = mAnswer[iAnswer] or ""
    local pid = oPlayer.m_iPid
    local oNpc = self:GetNpcObj(npcid)
    self:DoScriptCallbackUnit(pid, oNpc, s, mArgs or {})
end

function CTask:NotifyMsg(pid, npcobj, sType, sMsg)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    if sType == "1" then
        oPlayer:NotifyMessage(sMsg)
    end
end

-- function CTask:GetOptionAnswer()
--     return self.m_tmp_option_answer
-- end

-- function CTask:SetOptionAnswer(iAnswer)
--     -- 玩家完成任务需要使用这个选项来做选择支
--     self.m_tmp_option_answer = iAnswer
-- end

function CTask:SayRespondText(pid,npcobj,sText, mMenuArgs, iMenuType)
    if not npcobj then
        return
    end
    local taskid = self.m_ID
    local npcid = npcobj.m_ID
    local resFunc = function (oPlayer,mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if not oTask then
            return false
        end
        return oTask:OnSayRespondCanCallback(oPlayer, npcid, mData)
    end
    local cbFunc = function (oPlayer,mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, taskid, true)
        if not oTask then
            return
        end
        oTask:OnSayRespondCallback(oPlayer, npcid, mData)
    end
    npcobj:SayRespond(pid,sText,resFunc,cbFunc, mMenuArgs, iMenuType, true)
end


-- TransString的各指令执行方法
function CTask:TransStringFuncSubmitScene(pid,npcobj)
    local iType = self:Target()
    local oNpc = self:GetNpcObjByType(iType)
    if oNpc then
        local iMap = oNpc.m_iMapid
        local oSceneMgr = global.oSceneMgr
        local sSceneName = oSceneMgr:GetSceneName(iMap)
        return global.oToolMgr:FormatColorString("#submitscene", {submitscene = sSceneName})
    else
        assert(oNpc,string.format("CTask:TransString.submitscene %s %s %s",pid,self.m_ID,iType))
    end
end

function CTask:TransStringFuncSubmitNpc(pid,npcobj)
    local iType = self:Target()
    local oNpc = self:GetNpcObjByType(iType)
    if oNpc then
        return global.oToolMgr:FormatColorString("#submitnpc", {submitnpc = oNpc:Name()})
    else
        assert(oNpc,string.format("TransString.submitnpc err:%s %s %s",pid,self.m_ID,iType))
    end
end

function CTask:TransStringFuncMonster(pid,npcobj)
    local iType = self:TaskType()
    if iType == gamedefines.TASK_TYPE.TASK_ANLEI then
        local mData = self:GetData("anlei",{})
        for iMap, mAnlei in pairs(mData) do
            local iEvent,iDoneCnt,iNeedCnt,iMonsterIdx = table.unpack(mAnlei)
            local sName
            if iMonsterIdx then
                local mMonster = self:GetMonsterData(iMonsterIdx)
                if mMonster then
                    sName = mMonster.name
                    if string.sub(sName, 1, 1) == '$' then
                        sName = nil
                    end
                end
            end
            if not sName then
                local oTargetNpc = self:GetNpcObjByType(self:Target())
                if oTargetNpc then
                    sName = oTargetNpc:Name()
                else
                    sName = "敌人" -- 命中这里说明配表有问题
                end
            end
            return global.oToolMgr:FormatColorString("#monster", {monster = sName})
        end
    end
end

function CTask:TransStringFuncMonsterScene(pid,npcobj)
    local iType = self:TaskType()
    if iType == gamedefines.TASK_TYPE.TASK_ANLEI then
        local mData = self:GetData("anlei",{})
        for iMap, mAnlei in pairs(mData) do
            local oSceneMgr = global.oSceneMgr
            local sSceneName = oSceneMgr:GetSceneName(iMap)
            return global.oToolMgr:FormatColorString("#monsterscene", {monsterscene = sSceneName})
        end
    end
end

function CTask:TransStringFuncMap(pid,npcobj)
    local iType = self:TaskType()
    local iMapid
    local sMapName = ""
    if iType == gamedefines.TASK_TYPE.TASK_SAY then
        local mSayInfo = self:GetData("sayinfo")
        if not mSayInfo.mapid then
            return  sMapName
        end
        iMapid = mSayInfo.mapid
    else
        local iType = self:Target()
        if not iType then
            return sMapName
        end
        local oNpc = self:GetNpcObjByType(iType)
        if not oNpc then
            return sMapName
        end
        iMapid = oNpc:MapId()
    end
    local scenelist = global.oSceneMgr:GetSceneListByMap(iMapid)
    if #scenelist<=0 then
        return sMapName
    end
    local oScene = scenelist[1]
    local sSceneName = oScene:GetName()
    sMapName = global.oToolMgr:FormatColorString("#map", {map = sSceneName})
    return sMapName
end

function CTask:TransStringFuncCounting(pid,npcobj)
    local iType = self:TaskType()
    local sMsg
    if iType == gamedefines.TASK_TYPE.TASK_PICK then
        local iNeedCnt = self.m_iPickItemSum
        local iDoneCnt = iNeedCnt - table_count(self.m_lPickItem)
        sMsg = string.format("(%d/%d)", iDoneCnt, iNeedCnt)
    elseif iType == gamedefines.TASK_TYPE.TASK_ANLEI then
        local mData = self:GetData("anlei",{})
        for iMap, mAnlei in pairs(mData) do
            local iEvent,iDoneCnt,iNeedCnt,iMonsterIdx = table.unpack(mAnlei)
            sMsg = string.format("(%d/%d)", iDoneCnt, iNeedCnt)
        end
    elseif iType == gamedefines.TASK_TYPE.TASK_BEHAVIOR then
        local mBehaviorInfo = self.m_mBehaviorCnt
        if mBehaviorInfo then
            local iDoneCnt = mBehaviorInfo.done_cnt
            local iNeedCnt = mBehaviorInfo.max_cnt
            sMsg = string.format("(%d/%d)", iDoneCnt, iNeedCnt)
        end
    end
    return sMsg or ""
end

function CTask:TransStringFuncCount(pid,npcobj)
    local mData
    local iAmount
    local iType = self:TaskType()
    if iType == gamedefines.TASK_TYPE.TASK_FIND_ITEM then
        mData = self.m_mNeedItem
        if not next(mData) then
            mData = self.m_mNeedItemGroup
        end
    elseif iType == gamedefines.TASK_TYPE.TASK_FIND_SUMMON then
        mData = self.m_mNeedSummon
    elseif iType == gamedefines.TASK_TYPE.TASK_ANLEI then
        local mData = self:GetData("anlei",{})
        for iMap, mAnlei in pairs(mData) do
            local iEvent,iDoneCnt,iNeedCnt,iMonsterIdx = table.unpack(mAnlei)
            iAmount = iNeedCnt
            break
        end
    else
        return
    end

    if iAmount then
        return global.oToolMgr:FormatColorString("#amount", {amount = iAmount})
    end
    for _, iAmount in pairs(mData) do
        return global.oToolMgr:FormatColorString("#amount", {amount = iAmount})
    end
end

function CTask:GetTaskItemName(pid, npcobj)
    if next(self.m_mNeedItem) then
        for itemsid,iAmount in pairs(self.m_mNeedItem) do
            return global.oItemLoader:GetItemNameBySid(itemsid)
        end
    elseif next(self.m_mNeedItemGroup) then
        for groupid,iAmount in pairs(self.m_mNeedItemGroup) do
            return global.oItemLoader:GetItemGroupName(groupid)
        end
    elseif next(self.m_lUseTaskItem) then
        for _, mUseItemInfo in pairs(self.m_lUseTaskItem) do
            local itemsid = mUseItemInfo.itemid
            local mData = self:GetTaskItemData(itemsid)
            if mData then
                return mData.name
            end
        end
    elseif next(self.m_lPickItem) then
        for _, mPickItemInfo in pairs(self.m_lPickItem) do
            local pickid = mPickItemInfo.pickid
            return self:GetPickData(pickid).name
        end
    end
end

function CTask:TransStringFuncItem(pid, npcobj)
    local sName = self:GetTaskItemName(pid, npcobj)
    if sName then
        return global.oToolMgr:FormatColorString("#item", {item = sName})
    end
end

function CTask:TransStringFuncSummon(pid,npcobj)
    for summSid, iAmount in pairs(self.m_mNeedSummon) do
        local sSummonName = loadsummon.GetSummonNameBySid(summSid)
        return global.oToolMgr:FormatColorString("#summon", {summon = sSummonName})
    end
end

local mTransStringFuncs = {
    summon       = "TransStringFuncSummon",
    item         = "TransStringFuncItem",
    count        = "TransStringFuncCount",
    counting     = "TransStringFuncCounting",
    submitnpc    = "TransStringFuncSubmitNpc",
    submitscene  = "TransStringFuncSubmitScene",
    monsterscene = "TransStringFuncMonsterScene",
    monster      = "TransStringFuncMonster",
    map = "TransStringFuncMap",
}

function CTask:TransFuncTable()
    return mTransStringFuncs
end

function CTask:TransString(pid,npcobj,s)
    if not s then
        return s
    end
    if string.find(s,"$owner") then
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            s = gsub(s,"$owner", global.oToolMgr:FormatColorString("#role", {role = oPlayer:GetName()}))
        end
    end
    -- use string.match(s, '%$owner') & string.gmatch(s, '{(.-)}')
    local itMatch = string.gmatch(s, '{(.-)}')
    local mParsed = {}
    local mCmdTable = self:TransFuncTable()
    for sCmd in itMatch do
        if not mParsed[sCmd] then
            mParsed[sCmd] = true
            local f
            local sFuncName = mCmdTable[sCmd]
            if sFuncName then
                f = self[sFuncName]
            end
            if f then
                local sParseUnit = f(self, pid, npcobj)
                if sParseUnit then
                    local sPatten = string.format("{%s}", sCmd)
                    s = gsub(s, sPatten, {[sPatten] = sParseUnit})
                end
            end
        end
    end
    return s
end

function CTask:IsTeamTask()
end

function CTask:PackBackendInfo()
    return {
        taskid = self:GetId(),
        name = self:Name(),
        tasktype = self:Type(),
        accepttime = self:GetCreateTime(),
    }
end

function CTask:PackInfoTaskid()
    return self:GetId()
end

function CTask:PackInfoTarget()
    return self:Target()
end

function CTask:PackInfoName()
    return self:Name()
end

function CTask:PackInfoTargetDesc()
    local sDesc = self:TargetDesc()
    if self:IsForbidSubmit() then
        return "#R" .. sDesc .. "#n"
    end
    return sDesc
end

function CTask:PackInfoDetailDesc()
    return self:DetailDesc()
end

function CTask:PackInfoIsReach()
    if self:IsForbidSubmit() then
        return 0
    end
    return self.m_tmp_bReach and 1 or 0
end

-- @Overrideable
function CTask:BuildExtApplyInfo()
    -- body, return mapping {sKey-iValue}
end

function CTask:PackExtApplyInfo()
    local mExtInfo = self:BuildExtApplyInfo()
    if not mExtInfo then
        return nil
    end
    local lPacked = {}
    for sKey, iValue in pairs(mExtInfo) do
        table.insert(lPacked, {
            key = sKey,
            value = iValue,
        })
    end
    return lPacked
end

local mPackInfoFunc = {
    taskid = "PackInfoTaskid",
    target = "PackInfoTarget",
    name = "PackInfoName",
    targetdesc = "PackInfoTargetDesc",
    detaildesc = "PackInfoDetailDesc",
    isreach = "PackInfoIsReach",
    ext_apply_info = "PackExtApplyInfo",
    time = "Timer",
}
local mDefaultPackInfos = {
    taskid = true,
    target = true,
    name = true,
    targetdesc = true,
    detaildesc = true,
    isreach = true,
}

function CTask:PackTaskRefreshInfo(mRefreshKeys)
    local mNet = {}
    if not mRefreshKeys then
        mRefreshKeys = mDefaultPackInfos
    end
    mRefreshKeys.taskid = true
    for sKey, _ in pairs(mRefreshKeys) do
        local sFunc = mPackInfoFunc[sKey]
        if sFunc then
            mNet[sKey] = self[sFunc](self)
        end
    end
    return net.Mask("GS2CRefreshTask", mNet)
end

function CTask:Refresh(mRefreshKeys)
    if self.m_bIniting then
        return false
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    if oPlayer then
        oPlayer:Send("GS2CRefreshTask", self:PackTaskRefreshInfo(mRefreshKeys))
    end
    return true
end

function CTask:SendReach()
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self.m_Owner)
    local mNet = {
        taskid = self:GetId(),
        isreach = self:PackInfoIsReach(),
    }
    mNet = net.Mask("GS2CRefreshTask", mNet)
    if oPlayer then
        oPlayer:Send("GS2CRefreshTask", mNet)
    end
end

function CTask:PackFollowNpcsSceneInfo()
    local mNet = {}
    for npcid, oFollowNpc in pairs(self.m_mFollowNpc) do
        table.insert(mNet, oFollowNpc:FollowerInfo())
    end
    if not next(mNet) then
        return nil
    end
    return mNet
end

function CTask:GS2CDialog(oPlayer, mNet, cbFunc)
    local iPid = oPlayer:GetPid()
    if cbFunc then
        local oCbMgr = global.oCbMgr
        oCbMgr:SetCallBack(iPid, "GS2CDialog", mNet, nil, cbFunc)
        return
    end
    mNet.noanswer = 1
    oPlayer:Send("GS2CDialog",mNet)
end

function CTask:GetNeedItemSids()
    local mRet = {}
    local mNeedItem = self:NeedItem()
    local mNeedItemGroup = self:NeedItemGroup()
    for iItemSid, iAmount in pairs(mNeedItem) do
        if iAmount > 0 then
            mRet[iItemSid] = true
        end
    end
    for iGroupid, iAmount in pairs(mNeedItemGroup) do
        if iAmount > 0 then
            local lGroupItems = global.oItemLoader:GetItemGroup(iGroupid)
            for _, iItemSid in ipairs(lGroupItems) do
                mRet[iItemSid] = true
            end
        end
    end
    return mRet
end

function CTask:PackNeedItem()
    local mData = {}
    local mNeedItem = self:NeedItem()
    for itemsid,amount in pairs(mNeedItem) do
        table.insert(mData,{itemid=itemsid,amount=amount})
    end
    if table_count(mData) == 0 then
        return nil
    end
    return mData
end

function CTask:PackNeedItemGroup()
    local mData = {}
    local mNeedItemGroup = self:NeedItemGroup()
    for groupid,amount in pairs(mNeedItemGroup) do
        table.insert(mData,{groupid=groupid,amount=amount})
    end
    if table_count(mData) == 0 then
        return nil
    end
    return mData
end

function CTask:PackNeedSummon()
    local mData = {}
    local mNeedSum = self:NeedSummon()
    for sumid,amount in pairs(mNeedSum) do
        table.insert(mData,{sumid=sumid,amount=amount})
    end
    if table_count(mData) == 0 then
        return nil
    end
    return mData
end

function CTask:PackOneClientNpc(oClientNpc)
    return oClientNpc:PackInfo()
end

function CTask:PackClientNpc(oClientNpc)
    local lClientData = {}
    for _,oClientNpc in pairs(self.m_mClientNpc) do
        table.insert(lClientData, self:PackOneClientNpc(oClientNpc))
    end
    return lClientData
end

function CTask:PackFollowNpc()
    local lFollowData = {}
    for _,oFollowNpc in pairs(self.m_mFollowNpc) do
        table.insert(lFollowData, oFollowNpc:PackInfo())
    end
    return lFollowData
end

function CTask:PackUseTaskItem()
    return self.m_lUseTaskItem
end

function CTask:PackTaskInfo()
    local lIgnore = res["daobiao"]["kuafu"][1]["task_show"]
    if is_ks_server() and not extend.Array.member(lIgnore, self:Type()) then
        return {}
    end

    local mNet = {}
    mNet["taskid"] = self:PackInfoTaskid()
    mNet["create_time"] = self.m_iCreateTime or 0
    mNet["tasktype"] = self:TaskType()
    mNet["name"] = self:PackInfoName()
    mNet["targetdesc"] = self:PackInfoTargetDesc()
    mNet["detaildesc"] = self:PackInfoDetailDesc()
    mNet["target"] = self:PackInfoTarget()
    mNet["isdone"] = self:PackIsDone()
    mNet["isreach"] = self:PackInfoIsReach()
    -- FIXME 这个值取出是table，协议定义是int，考虑调整导表
    -- mNet["rewardinfo"] = self:RewardInfo()
    mNet["time"] = self:Timer()

    mNet["needitem"] = self:PackNeedItem()
    mNet["needitemgroup"] = self:PackNeedItemGroup()
    mNet["needsum"] = self:PackNeedSummon()
    mNet["taskitem"] = self:PackUseTaskItem()
    mNet["pickitem"] = self.m_lPickItem

    mNet["clientnpc"] = self:PackClientNpc()
    -- mNet["follownpc"] = self:PackFollowNpc()
    mNet["ext_apply_info"] = self:PackExtApplyInfo()
    return mNet
end

function CTask:CheckFuncReachFindItem()
    return self:ValidTakeItem(self:GetOwner())
end

function CTask:CheckFuncReachFindSummon()
    return self:ValidTakeSummon(self:GetOwner())
end

function CTask:CheckFuncReachPickItems()
    return table_count(self.m_lPickItem or {}) == 0
end

function CTask:CheckFuncReachUseTaskItems()
    return table_count(self.m_lUseTaskItem or {}) == 0
end

function CTask:CheckFuncReachConditions()
    return self:ValidTaskConditions() ~= CONDI_VALID.INVALID
end

-- @return: bReach, bDone
function CTask:CheckFuncReachBehavior()
    if self:IsBehaviorFullDone() then
        local npctype = self:Target()
        if npctype then
            return true, false
        else
            return true, true
        end
    end
end

-- @return: bReach, bDone
function CTask:CheckFuncReachQte()
    local iDoingQteId = self:GetData("doing_qte")
    if iDoingQteId then
        self:SetData("doing_qte", nil)
        local bStepDone, bClear = self:StepQte(iDoingQteId, 0)
        return bStepDone, bClear
    end
    if not self:HasQteStep() then
        local npctype = self:Target()
        if not npctype then
            return true, true
        else
            return true, false
        end
    end
end

-- @return: bDone, bClear
function CTask:StepQte(iQteId, iAnswer)
    if not iQteId then
        return
    end
    local mQteData = self.m_lPosQte[1]
    if not mQteData or iQteId ~= mQteData.qteid then
        return
    end
    if iAnswer == 1 or mQteData.forthdone then
        table.remove(self.m_lPosQte, 1)
        self:Dirty()
        if #self.m_lPosQte == 0 then
            return true, true
        else
            return true, false
        end
    end
end

function CTask:IsForbidSubmit()
    local mTaskData = global.oTaskLoader:GetTaskBaseData(self:GetId())
    if (mTaskData.forbid_submit or 0) ~= 0 then
        return true
    end
end

-- 这个函数表只在CTask:CheckTaskReached()中使用，此方法不重载，热更后子类依然查找本table
local mFuncCheckReached = {
    [gamedefines.TASK_TYPE.TASK_UPGRADE] = "CheckFuncReachConditions",
    [gamedefines.TASK_TYPE.TASK_QTE] = "CheckFuncReachQte",
    [gamedefines.TASK_TYPE.TASK_BEHAVIOR] = "CheckFuncReachBehavior",
}

function CTask:CheckFuncIsConditionCanSubmit(oNpc)
    return self:ValidTaskConditions() ~= CONDI_VALID.INVALID
end

function CTask:CheckFuncIsItemEnough(oNpc)
    return self:ValidTakeItem(self:GetOwner(), oNpc)
end

function CTask:CheckFuncIsSummEnough(oNpc)
    return self:ValidTakeSummon(self:GetOwner(), oNpc)
end

function CTask:CheckFuncAlwaysTrue(oNpc)
    return true
end

-- 这张表的调用CTask:CanTaskSubmit不可重载
local mFuncCheckCanSubmit = {
    [gamedefines.TASK_TYPE.TASK_UPGRADE] = "CheckFuncIsConditionCanSubmit",
    [gamedefines.TASK_TYPE.TASK_FIND_ITEM] = "CheckFuncIsItemEnough",
    [gamedefines.TASK_TYPE.TASK_FIND_SUMMON] = "CheckFuncIsSummEnough",
    [gamedefines.TASK_TYPE.TASK_FIND_NPC] = "CheckFuncAlwaysTrue",
    [gamedefines.TASK_TYPE.TASK_NPC_FIGHT] = "CheckFuncAlwaysTrue",
}
-- @FobidOverride
-- @return: bReach, bDone
function CTask:CheckTaskReached()
    local iType = self:TaskType()
    local func = self[mFuncCheckReached[iType]]
    if func then
        return func(self)
    end
    return false
end

-- @FobidOverride
function CTask:CanTaskSubmit(oNpc)
    if self.m_tmp_bReach then
        return true
    end
    local iType = self:TaskType()
    local func = self[mFuncCheckCanSubmit[iType]]
    if func then
        return func(self, oNpc)
    end
    return false
end

-- 这个方法是在上层的遍历内部，则上层需要注意不能遍历task本身的容器，只能遍历key_list
function CTask:OnLogin(oPlayer, bReEnter)
    if self:IsTimeOut() then
        self:TimeOut()
        return false
    end

    local bReach, bDone = self:CheckTaskReached()
    self.m_tmp_bReach = bReach
    if bDone then
        if self:TryMissionDone() then
            return false
        end
    end
    if not bReEnter then
        self:Setup()
    end
    return true
end

function CTask:OnLogout(oPlayer)
end

function CTask:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    local oRewardMonitor = global.oTaskMgr:GetTaskRewardMonitor()
    if oRewardMonitor and not oRewardMonitor:CheckRewardGroup(iPid, self.m_sName, iRewardId, iCnt, mArgs) then
        return false
    end
    return true
end

function CTask:LogReward(oPlayer, sIdx, mRewardContent, mArgs)
    local mLogData = oPlayer:LogData()
    -- TODO 这份content有问题，有些内容还没有转换成int
    local mContentCopy = self:SimplifyReward(oPlayer, mRewardContent or {}, mArgs)
    mLogData.reward = mContentCopy
    mLogData.owner = self:GetOwner() or 0
    mLogData.taskid = self:GetId()
    mLogData.rewardid = tonumber(sIdx)
    record.user("task", "reward", mLogData)
end

function CTask:Reward(pid, sIdx, mArgs)
    local mRewardContent = super(CTask).Reward(self, pid, sIdx, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer and mRewardContent then
        self:LogReward(oPlayer, sIdx, mRewardContent, mArgs)

        local bIsFight = self:TaskType() == gamedefines.TASK_TYPE.TASK_NPC_FIGHT
        local bIsTrunk = self:Type() == taskdefines.TASK_KIND.TRUNK
        local bIsBranch = self:Type() == taskdefines.TASK_KIND.BRANCH
        if bIsFight and (bIsTrunk or bIsBranch) then
            self:_AssistReward(pid, mRewardContent)
        end
    end
    return mRewardContent
end

--主线和支线战斗的队员协助奖励
function CTask:_AssistReward(iPid, mRewardContent)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not (oPlayer and oPlayer:HasTeam() and oPlayer:IsTeamLeader()) then
        return
    end

    local iType = self:Type()
    local mData = self:GetAssistData()
    local iScale = mData.reward_scale
    if not iScale then return end
    local iTaskId = self:GetId()

    local iSilver = mRewardContent.silver and math.floor(mRewardContent.silver * iScale / 100) or 0
    local iExp = mRewardContent.exp and math.floor(mRewardContent.exp * iScale / 100) or 0
    local iGold = mRewardContent.gold and math.floor(mRewardContent.gold * iScale / 100) or 0

    local lMember = oPlayer:GetTeamMember()
    for _, iMemPid in ipairs(lMember) do
        local oMember = global.oWorldMgr:GetOnlinePlayerByPid(iMemPid)
        if iMemPid ~= iPid and oMember and not oMember.m_oTaskCtrl:HasTask(iTaskId) then
            self:_AssistRewardOne(iMemPid, iExp, iSilver, iGold)
        end
    end
end

function CTask:_AssistRewardOne(iPid, iExp, iSilver, iGold)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mData = self:GetAssistData()
    local sMaxAssistExp = mData.max_exp
    if not sMaxAssistExp then return end

    local iMaxAssistExp = formula_string(sMaxAssistExp, { lv = oPlayer:GetGrade() })
    local iCurExp = oPlayer.m_oTodayMorning:Query("task_assist_exp", 0)
    if iCurExp >= iMaxAssistExp then
        local sMsg = self:GetTextData(2004)
        oPlayer:NotifyMessage(sMsg)
        return
    end

    local lTipMsg = {}
    local sReason = "主线或支线任务战斗协助"
    local mArgs = { cancel_tip = true, cancel_chat = true }
    iExp = math.min(iExp, iMaxAssistExp - iCurExp)
    if iExp > 0 then
        oPlayer.m_oTodayMorning:Add("task_assist_exp", iExp)
        oPlayer:RewardExp(iExp, sReason, mArgs)
        table.insert(lTipMsg, string.format("#G%d#n#cur_6", iExp))

        local mData = {
            assist_exp = oPlayer.m_oTodayMorning:Query("task_assist_exp", 0),
            max_assist_exp = iMaxAssistExp
        }
        oPlayer:Send("GS2CAssistExp", mData)
    end

    if iSilver > 0 then
        oPlayer:RewardSilver(iSilver, sReason, mArgs)
        table.insert(lTipMsg, string.format("#G%d#n#cur_4", iSilver))
    end

    if iGold > 0 then
        oPlayer:RewardGold(iGold, sReason, mArgs)
        table.insert(lTipMsg, string.format("#G%d#n#cur_3", iGold))
    end

    if #lTipMsg > 0 then
        local sMsg = table.concat(lTipMsg, ",")
        sMsg = global.oToolMgr:FormatColorString(self:GetTextData(2003), {reward = sMsg})
        oPlayer:NotifyMessage(sMsg)
        global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    end
end

-- @Override
function CTask:PackObjGetterInfo()
    return gamedefines.TEMPL_OBJ_TYPE.SINGLE_TASK, {
        pid = self:GetOwner(),
        taskid = self:GetId(),
    }
end

function CTask:TaskSay(oPlayer)
    local pid = oPlayer:GetPid()
    local oCbMgr = global.oCbMgr
    local oNotifyMgr = global.oNotifyMgr
    local mSayInfo = self:GetData("sayinfo")
    if not mSayInfo then
        oNotifyMgr:Notify(pid,"未配置喊话信息")
        return
    end
    local orgobj = oPlayer:GetOrg()
    if not orgobj then
        return
    end
    local sText = orgobj:GetAim()
    local iTaskID = self:GetId()
    local func = function (oPlayer,mData)
        local func2 = function(oPlayer,mData)
            local iTaskID = iTaskID
            local oTask = oPlayer.m_oTaskCtrl:HasTask(iTaskID)
            if not oTask then return end
            oTask:TrueTaskSay(oPlayer)
        end
        oCbMgr:SetCallBack(oPlayer:GetPid(),"GS2COpenTaskSayUI",{["text"] = sText,["channel"] = gamedefines.CHANNEL_TYPE.CURRENT_TYPE},nil,func2)
    end
    local mData = {["map_id"] = mSayInfo.mapid,["pos_x"] = mSayInfo.x ,["pos_y"] = mSayInfo.y ,["autotype"] = 1,["functype"] = gamedefines.FIND_PATH_FUNC_TYPE.TASKSAY}
    oCbMgr:SetCallBack(oPlayer:GetPid(),"AutoFindPath",mData,nil,func)
end

function CTask:TrueTaskSay(oPlayer, npcid)
    local pid = oPlayer
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr = global.oChatMgr
    local mSayInfo = self:GetData("sayinfo")
    local iSayType = mSayInfo.type
    local sText
    local orgobj = oPlayer:GetOrg()
    if orgobj then
        sText  = util.GetTextData(1009, {"huodong", "orgtask"})
        sText = string.format(sText,orgobj:OrgID(),orgobj:GetName())
    end
    if sText then
        if iSayType == 1 then
            oChatMgr:HandleWorldChat(oPlayer,sText)
        elseif iSayType  == gamedefines.CHANNEL_TYPE.CURRENT_TYPE then
            oChatMgr:HandleCurrentChat(oPlayer,sText,true)
        else
            record.warning(string.format("tasksay type %s %s %s",pid,oPlayer:GetOrgID(),iSayType))
        end
    else
        record.warning(string.format("tasksay %s %s",pid,oPlayer:GetOrgID()))
    end
    if not npcid then
        self:MissionDone()
    else
        local npcobj = self:GetNpcObj(npcid)
        self:MissionDone(npcobj)
    end
end

function CTask:OnExtendTaskUICallback(oPlayer, mData)
end

CTeamTask = {}
CTeamTask.__index = CTeamTask
inherit(CTeamTask,CTask)

function CTeamTask:New(taskid)
    local o = super(CTeamTask).New(self,taskid)
    o.m_mPlayer = {}
    o.m_iTeamID = nil
    return o
end

function CTeamTask:IsTeamTask()
    return true
end

-- @Override
function CTeamTask:GetCbSelfGetter()
    local iTeamid = self:GetTeamID()
    local iTaskid = self:GetId()
    return function()
        local oTeam = global.oTeamMgr:GetTeam(iTeamid)
        if not oTeam then
            return
        end
        return oTeam:GetTask(iTaskid)
    end
end

function CTeamTask:GS2CAddTask(iPid)
    super(CTeamTask).GS2CAddTask(self, iPid)
    -- TODO 跟随npc暂无，暂离情况会难处理
    -- if self:HasFollowNpc() then
    --     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    --     oPlayer.m_oTaskCtrl:RefreshFollowNpcs()
    -- end
end

function CTeamTask:AddPlayer(iPid)
    self.m_mPlayer[iPid] = 1
    self:GS2CAddTask(iPid)
end

function CTeamTask:OnTeamAddDone()
    self.m_bIniting = nil
end

function CTeamTask:SetTeamID(iTeamID)
    self.m_iTeamID = iTeamID
end

function CTeamTask:GetTeamID()
    return self.m_iTeamID
end

function CTeamTask:GetTeamObj()
    return global.oTeamMgr:GetTeam(self.m_iTeamID)
end

function CTeamTask:ValidDoScript(pid)
    return true
end

function CTeamTask:MissionDone(npcobj, mArgs)
    local oTeam = self:GetTeamObj()
    if oTeam then
        oTeam:MissionDone(self, npcobj, mArgs)
    end
end

function CTeamTask:NextTask(iTaskid, pid, npcobj, mArgs)
    local oTeam = self:GetTeamObj()
    if oTeam then
        oTeam:NextTask(self, iTaskid, npcobj, mArgs)
    end
end

function CTeamTask:GetOwner()
    for iPid, _ in pairs(self.m_mPlayer or {}) do
        return iPid
    end
    return nil
end

function CTeamTask:GetOwners()
    return self.m_mPlayer
end

function CTeamTask:CheckFighersOwnTask(oWar, pid, npcobj, mWarCbArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid) -- 可能不在线
    local lFighters = self:GetFighterList(oPlayer, mWarCbArgs)
    local lOwners = self:GetOwners()
    for _, iFighter in ipairs(lFighters) do
        if lOwners[iFighter] then
            return true
        end
    end
    return false
end

function CTeamTask:PostOwners(sNetCmd, mNet)
    for iPid, _ in pairs(self:GetOwners()) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send(sNetCmd, mNet)
        end
    end
end

-- @Override
function CTeamTask:IsWarTeamMembersShareDone(oWar, iWarCallerPid, npcobj, mWarCbArgs)
    return false
end

function CTeamTask:Detach()
    self:DelTimeCb("timeout")
    local oTeam = self:GetTeamObj()
    if oTeam then
        oTeam:DetachTask(self:GetId())
    end
end

function CTeamTask:Remove()
    self:Detach()
    local mPlayers = self.m_mPlayer
    self.m_mPlayer = {}
    for iPid,_ in pairs(mPlayers) do
        self:GS2CRemoveTask(iPid)
    end
    for iPid,_ in pairs(mPlayers) do
        -- TODO 队伍的Clear不同，一次清理所有人都需要下行
        self:Clear(iPid)
    end
end

function CTeamTask:AllowShortLeave()
end

function CTeamTask:OnLogin(oPlayer, bReEnter)
    local iPid = oPlayer:GetPid()
    if not self:AllowShortLeave() then
        local oTeam = self:GetTeamObj()
        if not oTeam:IsTeamMember(iPid) then
            return
        end
    end
    if self.m_mPlayer[iPid] then
        self:GS2CAddTask(iPid)
    end
    return true
end

function CTeamTask:EnterTeam(iPid,iFlag)
    if self.m_mPlayer[iPid] then
        return
    end
    self.m_mPlayer[iPid] = 1
    self:GS2CAddTask(iPid)
    safe_call(self.OnEnterTeam, self, iPid, iFlag)
end

function CTeamTask:OnEnterTeam(iPid,iFlag)
    if self:TaskType() == gamedefines.TASK_TYPE.TASK_ANLEI then
        self:RegAnleiForOne(iPid)
    end
end

function CTeamTask:LeaveTeam(iPid,iFlag)
    self.m_mPlayer[iPid] = nil
    self:GS2CRemoveTask(iPid)
    safe_call(self.OnLeaveTeam, self, iPid, iFlag)
end

function CTeamTask:OnLeaveTeam(iPid,iFlag)
    if self:TaskType() == gamedefines.TASK_TYPE.TASK_ANLEI then
        self:UnRegAnleiForOne(iPid)
    end
end

function CTeamTask:Refresh(mRefreshKeys)
    if self.m_bIniting then
        return false
    end
    local lOwners = self:GetOwners()
    local mNet = self:PackTaskRefreshInfo(mRefreshKeys)
    for iPid, _ in pairs(lOwners) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            oPlayer:Send("GS2CRefreshTask", mNet)
        end
    end
    return true
end

function CTeamTask:GS2CRemoveTask(iPid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CDelTask",{
        taskid = self:GetId(),
        is_done = self:PackIsDone(),
    })
end

function CTeamTask:BeforeSayRespond(oPlayer, npcid)
    local oNpc = self:GetNpcObj(npcid)
    if not oNpc then return false end
    return true
end

function CTeamTask:SayRespondText(pid, npcobj, sText, mMenuArgs, iMenuType)
    if not npcobj then return end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local iTask = self.m_ID
    local npcid = npcobj.m_ID

    local resFunc = function (oPlayer,mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTask, true)
        if not oTask then return false end
        return oTask:BeforeSayRespond(oPlayer, npcid)
    end

    local cbFunc = function (oPlayer,mData)
        local oTask = global.oTaskMgr:GetUserTask(oPlayer, iTask, true)
        if not oTask then
            return
        end
        oTask:OnSayRespondCallback(oPlayer, npcid, mData)
    end
    npcobj:SayRespond(pid,sText,resFunc,cbFunc, mMenuArgs, iMenuType, true)
end

function CTeamTask:GS2CDialog(oPlayer, mNet, cbFunc)
    local iPid = oPlayer:GetPid()
    if cbFunc then
        local oCbMgr = global.oCbMgr
        oCbMgr:SetCallBack(iPid, "GS2CDialog", mNet, nil, cbFunc)
    else
        mNet["noanswer"] = 1
        oPlayer:Send("GS2CDialog", mNet)
    end
    local mNet2 = extend.Table.clone(mNet)
    mNet2["noanswer"] = 1
    for iMemId, _ in pairs(self:GetOwners()) do
        if iMemId ~= iPid then
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(iMemId)
            if oMem then
                oMem:Send("GS2CDialog", mNet2)
            end
        end
    end
end

-- @Override
function CTeamTask:PackObjGetterInfo()
    return gamedefines.TEMPL_OBJ_TYPE.TEAM_TASK, {
        teamid = self:GetTeamID(),
        taskid = self:GetId(),
    }
end

function CTeamTask:OnChangeLeader(iPid)
end

