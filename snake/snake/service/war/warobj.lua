--import module

local global = require "global"
local skynet = require "skynet"
local playersend = require "base.playersend"
local interactive = require "base.interactive"

local status = import(lualib_path("base.status"))
local gamedefines = import(lualib_path("public.gamedefines"))
local playerwarrior = import(service_path("warrior.playerwarrior"))
local campobj = import(service_path("campobj"))
local npcwarrior = import(service_path("warrior.npcwarrior"))
local sumwarrior = import(service_path("warrior.sumwarrior"))
local warrecord = import(service_path("warrecord"))
local loadaction = import(service_path("action.loadaction"))
local partnerwarrior = import(service_path("warrior.partnerwarrior"))
local roplayerwarrior = import(service_path("warrior.roplayerwarrior"))
local rosumwarrior = import(service_path("warrior.rosumwarrior"))
local ropartnerwarrior = import(service_path("warrior.ropartnerwarrior"))
local observer = import(service_path("observer"))
local warbulletbarrage = import(service_path("warbulletbarrage"))

function NewWar(...)
    local o = CWar:New(...)
    return o
end

CWar = {}
CWar.__index = CWar
inherit(CWar, logic_base_cls())

function CWar:New(id)
    local o = super(CWar).New(self)
    o.m_iWarId = id
    o.m_iWarType = 0
    o.m_iDispatchId = 0

    o.m_lCamps = {campobj.NewCamp(1), campobj.NewCamp(2), campobj.NewCamp(3)}
    o.m_mWarriors = {}
    --o.m_mLeaveWarriors = {}         --用于处理对象release问题
    o.m_mPlayers = {}
    o.m_mPartners = {}
    o.m_mWatcher = {}
    o.m_mObservers = {}
    o.m_mEscape={{},{},{}}

    o.m_bWholeAIFight = false
    o.m_bWarEnd = false
    o.m_iWarResult = nil
    o.m_iBout = 0
    o.m_oBoutStatus = status.NewStatus()
    o.m_oBoutStatus:Set(gamedefines.WAR_BOUT_STATUS.NULL)
    o.m_mBoutCmds = {}
    o:ResetOperateTime()
    o:ResetAnimationTime()
    o.m_oRecord = warrecord.NewRecord(o.m_iWarId)
    o.m_oBulletBarrage = warbulletbarrage.NewBulletBarrage(o.m_iWarId)
    o.m_Appoint = {}
    o.m_iAction = 0
    o.m_mBoutRevive = {}

    o.m_mDebugPlayer = {}
    o.m_mDebugMsgQueue = {}
    o.m_mDebugMsg = {}

    o.m_mConfig = {}
    o.m_mExtData = {}
    o.m_mBoutOutInfo = {bout=99, result=1}
    o.m_mWarBackArgs = {}
    o.m_iStartAnimationTime = 0
    o.m_iStartTime = get_time()
    return o
end

function CWar:Release()
    for _, v in ipairs(self.m_lCamps) do
        baseobj_safe_release(v)
    end
--    for _, v in ipairs(self.m_mLeaveWarriors) do
--        baseobj_safe_release(v)
--    end
    baseobj_safe_release(self.m_oBoutStatus)
    baseobj_safe_release(self.m_oRecord)
    baseobj_safe_release(self.m_oBulletBarrage)
    if self.m_oSpeekCtrl then
        baseobj_safe_release(self.m_oSpeekCtrl)
    end
    super(CWar).Release(self)
end

function CWar:Init(iWarType, mInit)
    self.m_iWarType = iWarType
    if mInit.wholeai then
        self.m_bWholeAIFight = true
    end
    if mInit.sky_war then
        self.m_iSkyWar = true
    end
    if mInit.weather then
        self.m_iWeather = mInit.weather
    end
    if mInit.is_bosswar then
        self.m_bIsBossWar = true
    end
    if mInit.auto_start then
        self.m_iAutoStart = mInit.auto_start
    end
    if mInit.bout_out then
        self.m_mBoutOutInfo = mInit.bout_out
    end
    if mInit.war_record then
        self.m_iWarRecord = mInit.war_record
    end
    self:AddDebugMsg(string.format("基础信息："),true)
end

function CWar:IsAutoStart()
    return self.m_iAutoStart == 1
end

function CWar:GetAutoStart()
    return self.m_iAutoStart or 0
end

function CWar:IsBossWar()
    return self.m_bIsBossWar
end

function CWar:IsWholeAIFight()
    return self.m_bWholeAIFight
end

function CWar:IsSkyWar()
    return self.m_iSkyWar
end

function CWar:GetWeather()
    return self.m_iWeather or 0
end

function CWar:DispatchWarriorId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CWar:IsWarRecord()
    return self.m_iWarRecord == 1
end

function CWar:GetWarId()
    return self.m_iWarId
end

function CWar:GetWarType()
    return self.m_iWarType
end

function CWar:GetWatcherMap()
    return self.m_mWatcher
end

function CWar:AddWatcher(oWatcher)
    self.m_mWatcher[oWatcher:GetWid()] = true
end

function CWar:DelWatcher(oWatcher)
    self.m_mWatcher[oWatcher:GetWid()] = nil
end

function CWar:WarriorCount()
    return table_count(self.m_mWarriors)
end

function CWar:GetWarriorMap()
    return self.m_mWarriors
end

function CWar:BoutCmdLen()
    return table_count(self.m_mBoutCmds)
end

function CWar:CheckBoutCmdEnough()
    if self.m_iBoutAICommand then
        return
    end
    local iCnt = 0
    for k,_ in pairs(self.m_mWarriors) do
        local o = self:GetWarrior(k)
        if o:IsPlayer() or o:IsSummon() then
            iCnt = iCnt + 1
        end
    end

    if self:BoutCmdLen() >= iCnt and self.m_oBoutStatus:Get() == gamedefines.WAR_BOUT_STATUS.OPERATE then
        self:AI()
        self:BoutProcess()
    end
end

function CWar:AI()
    self.m_iBoutAICommand = true

    local lWarriors  = table_key_list(self.m_mWarriors)
    for _, iWid in ipairs(lWarriors) do
        local oAction = self:GetWarrior(iWid)
        if oAction and not self:GetBoutCmd(iWid) then
            safe_call(oAction.AICommand, oAction)
        end
    end
end

function CWar:AddBoutCmd(iWid, mCmd)
    if self.m_oBoutStatus:Get() == gamedefines.WAR_BOUT_STATUS.OPERATE then
        self.m_mBoutCmds[iWid] = mCmd
        local oWarrior = self:GetWarrior(iWid)
        if oWarrior and (oWarrior:IsPlayer() or oWarrior:IsSummon()) then
            oWarrior:StatusChange("cmd")
        end
        self:CheckBoutCmdEnough()
    end
end

function CWar:DelBoutCmd(iWid)
    self.m_mBoutCmds[iWid] = nil
end

function CWar:GetBoutCmd(iWid)
    return self.m_mBoutCmds[iWid]
end

function CWar:AddBoutRevive(oWarrior)
    if not oWarrior then return end
    local iWid = oWarrior:GetWid()
    if not self:GetBoutCmd(iWid) then return end

    local iWid = oWarrior:GetWid()
    self.m_mBoutRevive[iWid] = {iWid, self:CurAction(), oWarrior:GetSpeed()}
end

function CWar:GetReviveSpeed()
    local lSpeedSort = {}
    for _, m in pairs(self.m_mBoutRevive) do
        table.insert(lSpeedSort, m)
    end
    table.sort(lSpeedSort, function (a, b)
        if a[2] == b[2] then
            return a[3] < b[3]
        else
            return a[2] > b[2]
        end
    end)
    local mSpeed, iSpeed = {}, 100
    for _, m in pairs(lSpeedSort) do
        mSpeed[m[1]] = iSpeed
        iSpeed = iSpeed + 10
    end
    return mSpeed
end

function CWar:GetWarrior(id)
    local iCamp = self.m_mWarriors[id]
    if iCamp then
        return self.m_lCamps[iCamp]:GetWarrior(id)
    end
end

function CWar:GetWarriorByPos(iCamp,iPos)
    local oCamp = self.m_lCamps[iCamp]
    if oCamp then
        return oCamp:GetWarriorByPos(iPos)
    end
end

function CWar:GetWarriorList(iCamp)
    local oCamp = self.m_lCamps[iCamp]
    if oCamp then
        return oCamp:GetWarriorList()
    end
end

function CWar:GetCampDeadNum(iCamp)
    local oCamp = self.m_lCamps[iCamp]
    if oCamp then
        return oCamp:GetDeadNum()
    end
    return 0
end

function CWar:AddCampDeadNum(iCamp, iCnt)
    local oCamp = self.m_lCamps[iCamp]
    if oCamp then
        return oCamp:AddDeadNum(iCnt)
    end
end

function CWar:GetPlayerWarriorList()
    local mWarriors = {}
    for iPid, iWid in pairs(self.m_mPlayers) do
        local oWarrior = self:GetWarrior(iWid)
        if oWarrior then
            table.insert(mWarriors, oWarrior)
        end
    end
    return mWarriors
end

function CWar:GetPlayerWarrior(iPid)
    local id = self.m_mPlayers[iPid]
    return self:GetWarrior(id)
end

function CWar:GetObserverByPid(iPid)
    return self.m_mObservers[iPid]
end

--lxldebug
function CWar:ChooseRandomEnemy(obj)
    local iCamp = obj:GetCampId()
    local iCnt = math.random(1, 5)
    local l = {}
    for k, _ in pairs(self.m_mWarriors) do
        local o = self:GetWarrior(k)
        if o and o:GetCampId() ~= iCamp then
            table.insert(l, o)
            iCnt = iCnt - 1
            if iCnt <= 0 then
                break
            end
        end
    end
    return l
end

function CWar:Enter(obj, iCamp)
    self.m_lCamps[iCamp]:Enter(obj)
    self.m_mWarriors[obj:GetWid()] = iCamp
    return obj
end

function CWar:Leave(obj)
    self.m_lCamps[obj:GetCampId()]:Leave(obj)
    self.m_mWarriors[obj:GetWid()] = nil
    --self.m_mLeaveWarriors[obj:GetWid()] = obj
    baseobj_delay_release(obj)
end

function CWar:GS2CAddAllWarriors(obj)
    local mWarriorMap = self:GetWarriorMap()
    for k, _ in pairs(mWarriorMap) do
        if obj:IsObserver() or k ~= obj:GetWid() then
            local o = self:GetWarrior(k)
            if o then
                local mNet = {}
                mNet.war_id = o:GetWarId()
                mNet.camp_id = o:GetCampId()
                mNet.type = o:Type()
                if o:IsPlayer() then
                    mNet.warrior = o:GetSimpleWarriorInfo()
                elseif o:IsNpc() then
                    mNet.npcwarrior = o:GetSimpleWarriorInfo()
                elseif o:IsSummon() then
                    mNet.sumwarrior = o:GetSimpleWarriorInfo()
                elseif o:IsPartner() then
                    mNet.partnerwarrior = o:GetSimpleWarriorInfo()
                elseif o:IsRoPlayer() then
                    mNet.roplayerwarrior = o:GetSimpleWarriorInfo()
                elseif o:IsRoPartner() then
                    mNet.ropartnerwarrior = o:GetSimpleWarriorInfo()
                elseif o:IsRoSummon() then
                    mNet.rosummonwarrior = o:GetSimpleWarriorInfo()
                end
                obj:Send("GS2CWarAddWarrior", mNet)
            end
        end
    end
end

function CWar:EnterPlayer(iPid, iCamp, mInfo)
    assert(not self.m_mPlayers[iPid], string.format("EnterPlayer error %d", iPid))
    local iWid = self:DispatchWarriorId()
    local obj = playerwarrior.NewPlayerWarrior(iWid, iPid)
    self.m_mPlayers[iPid] = iWid
    obj:Init({
        camp_id = iCamp,
        war_id = self:GetWarId(),
        data = mInfo,
    })
    self:Enter(obj, iCamp)
    self:AddWatcher(obj)
    self:SendAll("GS2CWarAddWarrior", {
        war_id = obj:GetWarId(),
        camp_id = obj:GetCampId(),
        type = obj:Type(),
        warrior = obj:GetSimpleWarriorInfo(),
    })
    self:GS2CAddAllWarriors(obj)

    local mSumData = obj:GetData("summon")
    if mSumData then
        self:AddSummon(obj,mSumData)
    end
    obj:Send("GS2CPlayerWarriorEnter",{
        war_id = self.m_iWarId,
        wid = obj:GetWid(),
        sum_list = table_key_list(obj:Query("summon",{}))
    })
    return obj
end

function CWar:GetCampObj(iCamp)
    return self.m_lCamps[iCamp]
end

function CWar:AddSummon(oPlayer,mSumData,bSummon)
    local iCamp = oPlayer:GetCampId()
    local oCamp = self.m_lCamps[iCamp]
    local iPos = oCamp:GetSummonPos(oPlayer)
    local iWid = oPlayer:GetWid()
    local iSumWid = self:DispatchWarriorId()
    local mData = mSumData["sumdata"]

    local sum_id = mData["sum_id"]
    local mSummon = oPlayer:Query("summon",{})
    if mSummon[sum_id] then
        return
    end
    mSummon[sum_id] = iSumWid
    oPlayer:Set("summon",mSummon)
    oPlayer:Set("curr_sum", iSumWid)
    local oSummon = sumwarrior.NewSummonWarrior(iSumWid)
    if oSummon then
        mData["owner"] = iWid
        oSummon:Init({
            camp_id = iCamp,
            war_id = self:GetWarId(),
            data = mData,
        })
        -- oSummon:SetData("owner",iWid)
        self.m_lCamps[iCamp]:EnterSummon(oSummon,iPos)
        self.m_mWarriors[oSummon:GetWid()] = iCamp
        self:SendAll("GS2CWarAddWarrior", {
            war_id = oSummon:GetWarId(),
            camp_id = oSummon:GetCampId(),
            type = oSummon:Type(),
            sumwarrior = oSummon:GetSimpleWarriorInfo(),
            is_summon = bSummon and 1 or 0,
        })


        local mFunction = oPlayer:GetFunction("OnAddSummon")
        for _,fCallback in pairs(mFunction) do
            safe_call(fCallback, oPlayer, oSummon)
        end
    end
end

function CWar:EnterPartnerList(iOwner, iCamp, lInfo)
    for idx, mData in pairs(lInfo) do
        local iPid = mData.pid
        local iWid = self:DispatchWarriorId()
        local obj = partnerwarrior.NewPartnerWarrior(iWid, iOwner, iPid)
        obj:Init({
            camp_id = iCamp,
            war_id = self:GetWarId(),
            data = mData,
        })

        self.m_mPartners[iPid] = iWid
        self:Enter(obj, iCamp)
        self:SendAll("GS2CWarAddWarrior", {
            war_id = obj:GetWarId(),
            camp_id = obj:GetCampId(),
            type = obj:Type(),
            partnerwarrior = obj:GetSimpleWarriorInfo(),
        })
    end
end

function CWar:EnterRoPlayer(iCamp, mInfo)
    local iWid = self:DispatchWarriorId()
    local obj = roplayerwarrior.NewRoPlayerWarrior(iWid)
    obj:Init({
        camp_id = iCamp,
        war_id = self:GetWarId(),
        data = mInfo,
    })
    self:Enter(obj, iCamp)

    local mSumData = obj:GetData("summon")
    if mSumData and mSumData.sumdata then
        self:AddRoSummon(obj, mSumData.sumdata)
    end
    self:SendAll("GS2CWarAddWarrior", {
        war_id = obj:GetWarId(),
        camp_id = obj:GetCampId(),
        type = obj:Type(),
        roplayerwarrior = obj:GetSimpleWarriorInfo(),
    })
    return obj
end

function CWar:AddRoSummon(oPlayer, mData)
    local iCamp = oPlayer:GetCampId()
    local oCamp = self.m_lCamps[iCamp]
    local iPos = oCamp:GetSummonPos(oPlayer)
    local iSumWid = self:DispatchWarriorId()
    oPlayer:Set("curr_sum", iSumWid)
    local oSummon = rosumwarrior.NewRoSummonWarrior(iSumWid)
    oSummon:Init({
        camp_id = iCamp,
        war_id = self:GetWarId(),
        data = mData,
    })
    oSummon:SetData("owner",oPlayer:GetWid())
    oCamp:EnterSummon(oSummon,iPos)
    self.m_mWarriors[oSummon:GetWid()] = iCamp
    self:SendAll("GS2CWarAddWarrior", {
        war_id = oSummon:GetWarId(),
        camp_id = oSummon:GetCampId(),
        type = oSummon:Type(),
        rosummonwarrior = oSummon:GetSimpleWarriorInfo(),
    })
end

function CWar:EnterRoPartnerList(iCamp, lInfo)
    for idx, mData in ipairs(lInfo) do
        local iWid = self:DispatchWarriorId()
        local obj = ropartnerwarrior.NewRoPartnerWarrior(iWid)
        obj:Init({
            camp_id = iCamp,
            war_id = self:GetWarId(),
            data = mData,
        })
        self:Enter(obj, iCamp)
        self:SendAll("GS2CWarAddWarrior", {
            war_id = obj:GetWarId(),
            camp_id = obj:GetCampId(),
            type = obj:Type(),
            ropartnerwarrior = obj:GetSimpleWarriorInfo(),
        })
    end
end

function CWar:LeavePlayer(iPid,bEscape)
    local obj = self:GetPlayerWarrior(iPid)
    if obj then
        local iWid = obj:GetWid()
        self:SendAll("GS2CWarDelWarrior", {
            war_id = obj:GetWarId(),
            wid = obj:GetWid(),
            war_end = self.m_bWarEnd and 1 or 0,
        })

        obj:Send("GS2CWarResult", {
            war_id = self:GetWarId(),
            bout_id = self.m_iBout,
        })
        self:LeaveSummon(obj)
        self:LeavePartner(obj)

        if bEscape then
            table.insert(self.m_mEscape[obj:GetCampId()],iPid)
        end

        self.m_mPlayers[iPid] = nil
        self:DelWatcher(obj)
        obj:Leave() 
        interactive.Send(".world", "war", "RemoteEvent", {event = "remote_leave_player", data = {
            war_id = self:GetWarId(),
            pid = iPid,
            escape = bEscape,
            is_dead = obj:IsDead(),
            war_info = self.m_oRecord:PackRecordInfo(iPid),
            auto_pf = obj:GetAutoPerform(),
            sum_autopf = obj:GetSummAutoPf(),
            updateinfo = obj:GetUpdateInfo(),
            auto_fight = obj:GetAutoFight(),
        }})
        self:Leave(obj)
    end
end

function CWar:GetAllPartnerByOwner(iOwner)
    local lPartner = {}
    for iPid, iWid in pairs(self.m_mPartners) do
        local obj = self:GetWarrior(iWid)
        if not obj then
            goto continue
        end
        if obj:GetOwner() ~= iOwner then
            goto continue
        end
        table.insert(lPartner, iWid)
        ::continue::
    end
    return lPartner
end

function CWar:LeavePartner(oPlayer)
    local iOwner = oPlayer:GetPid()
    local lPartner = self:GetAllPartnerByOwner(iOwner)
    if not #lPartner then return end

    for _, iWid in ipairs(lPartner) do
        local obj = self:GetWarrior(iWid)
        if obj then
            self:SendAll("GS2CWarDelWarrior", {
                war_id = obj:GetWarId(),
                wid = iWid,
                war_end = self.m_bWarEnd and 1 or 0,
            })
            self.m_mPartners[obj:GetPid()] = nil
            obj:Leave()
            self:Leave(obj)
        end
    end
end

function CWar:LeaveSummon(oPlayer)
    local mSummon = oPlayer:Query("summon", {})
    local iSumWid = oPlayer:Query("curr_sum")
    if not iSumWid then return end

    local obj = self:GetWarrior(iSumWid)
    if not obj then return end

    self:SendAll("GS2CWarDelWarrior", {
        war_id = obj:GetWarId(),
        wid = iSumWid,
        war_end = self.m_bWarEnd and 1 or 0,
    })
    obj:Leave()
    self:Leave(obj)
end

function CWar:KickOutWarrior(oAction,iType)
    iType = iType or 1
    if oAction:IsPlayer() then
        self:LeavePlayer(oAction:GetPid())
    else
        local iWid = oAction:GetWid()
        self:SendAll("GS2CWarDelWarrior", {
            war_id = oAction:GetWarId(),
            wid = oAction:GetWid(),
            type = iType,
        })
        oAction:Leave()
        self:Leave(oAction)
    end
    if oAction:IsAlive() then
        oAction.m_oStatus:Set(gamedefines.WAR_WARRIOR_STATUS.DEAD)
    end
    local mFunction = oAction:GetFunction("AfterKickOut") or {}
    for _,fCallback in pairs(mFunction) do
        safe_call(fCallback, oAction)
    end
end

function CWar:ReEnterPlayer(iPid)
    local oWarrior = self:GetPlayerWarrior(iPid)
    if not oWarrior then
        return 
    end
    oWarrior:ReEnter()
end

function CWar:EnterObserver(iPid, mArgs)
    local oObserver = observer.NewObserver(iPid)
    mArgs = mArgs or {}
    mArgs.war_id = self:GetWarId()
    if mArgs.npc_id then
        mArgs.camp_id = 1
    elseif mArgs.target then
        local oWarrior = self:GetPlayerWarrior(mArgs.target)
        if oWarrior then
            mArgs.camp_id = oWarrior:GetCampId()
        end
    end
    if mArgs.camp_id and mArgs.camp_flag and mArgs.camp_flag ~= 1 then
        mArgs.camp_id = 3 - mArgs.camp_id
    end

    oObserver:Init(mArgs)
    self.m_mObservers[iPid] = oObserver
    oObserver:Enter()
    self:SendWarObCnt()
end

function CWar:LeaveObserver(iPid)
    if self.m_mObservers[iPid] then
        self.m_mObservers[iPid] = nil
        interactive.Send(".world", "war", "RemoteEvent", {event = "remote_leave_observer", data = {
            war_id = self:GetWarId(),
            pid = iPid,
        }})
        self:SendWarObCnt()
    end
end

function CWar:SendWarObCnt()
    self:SendAll("GS2CWarObCount", {
        war_id  = self:GetWarId(),
        ob_cnt = table_count(self.m_mObservers),
    })
end

function  CWar:WarBulletBarrage(sName,sMsg)
    local mData = self.m_oBulletBarrage:AddBulletBarrage(sName,sMsg)
    local iBout = mData.bout
    local iSecs = mData.secs

    self:SendAll("GS2CWarBulletBarrage", {
        war_id = self:GetWarId(),
        bout = iBout,
        secs = iSecs,
        name = sName,
        msg = sMsg,
    })
end

function CWar:AddOperateTime(iTime)
    self.m_iOperateWaitTime = self.m_iOperateWaitTime + iTime
end

function CWar:GetOperateTime()
    return self.m_iOperateWaitTime
end

function CWar:BaseOperateTime()
    return 1000
end

function CWar:ResetOperateTime()
    self.m_iOperateWaitTime = 0
end

function CWar:GetAnimationTime()
    return self.m_iAnimationWaitTime
end

function CWar:BaseAnimationTime()
    return 500
end

function CWar:AddAnimationTime(iTimeMS) -- 毫秒
    self.m_iAnimationWaitTime = self.m_iAnimationWaitTime + iTimeMS
end

function CWar:ResetAnimationTime()
    self.m_iAnimationWaitTime = 0
    self.m_iMaxAnimationTime = 0
    self.m_mAnimationEndTable = {}
end

function CWar:C2GSWarAnimationEnd(oWarrior, iBout)
    if self:IsWholeAIFight() then return end

    if not oWarrior:IsPlayer() then return end

    if self:CurBout() ~= iBout then return end

    local iPid = oWarrior:GetPid()
    local iCompareTime = self:GetAnimationTime()
    local iUseTime = (get_time(true)-self.m_iStartAnimationTime)*1000
    if iCompareTime <= 0 or iCompareTime - iUseTime > 6000 then
        return
    end

--    self.m_mAnimationEndTable[iPid] = true
--    local iVoteNum = math.ceil(table_count(self.m_mPlayers) / 2 + 0.5)
--    if table_count(self.m_mAnimationEndTable) >= iVoteNum then
        local iAliveCount1 = self.m_lCamps[1]:GetAliveCount()
        local iAliveCount2 = self.m_lCamps[2]:GetAliveCount()
        local iBoutOut = self.m_mBoutOutInfo.bout

        if iAliveCount1 > 0 and iAliveCount2 > 0 and iBout < iBoutOut then
            self:BoutStart()
        else
            self:WarEnd()
        end
--    end
end

function CWar:PrepareCamp(iCamp, mInfo)
    self.m_lCamps[iCamp]:Init(mInfo)
end

-- @mConfig: {record_add_npc.iMonsterIdx:1 记录npc怪物}
function CWar:WarPrepare(mInfo, mConfig)
    self.m_mConfig = mConfig or {}

    for iCamp,mSideData in pairs(mInfo) do
        for _, mInfo in ipairs(mSideData) do
            self:AddNpcWarrior(iCamp, mInfo)
        end
    end
end

function CWar:AddNpcWarrior(iCamp, mInfo, iPos, iAddType, bSummon)
    local iWid = self:DispatchWarriorId()
    local obj = npcwarrior.NewNpcWarrior(iWid)
    obj:Init({
        camp_id = iCamp,
        war_id = self:GetWarId(),
        data = mInfo,
    })
    
    if iPos then
       obj:SetPos(iPos) 
    end
    self:Enter(obj, iCamp)

    self:SendAll("GS2CWarAddWarrior", {
        war_id = obj:GetWarId(),
        camp_id = obj:GetCampId(),
        type = obj:Type(),
        npcwarrior = obj:GetSimpleWarriorInfo(),
        add_type = iAddType,
        is_summon = bSummon and 1 or 0,
    })

    -- rec warriorIdx:cnt, sendback when WarEnd
    local iMonsterIdx = mInfo.type
    local mConfRecAddNpc = self.m_mConfig.record_add_npc
    if mConfRecAddNpc and mConfRecAddNpc[iMonsterIdx] then
        self.m_oRecord:AddMonster(iCamp, iMonsterIdx)
    end
    self.m_oRecord:AddMonsterByWid(self, iCamp, iWid)

    return obj
end

function CWar:CalFormationEffect()
    self.m_lCamps[1]:CalFormationEffect(self.m_lCamps[2])

    self:SendAll("GS2CWarCampFmtInfo", {
        war_id = self:GetWarId(),
        fmt_id1 = self.m_lCamps[1]:GetFmtId(),
        fmt_grade1 = self.m_lCamps[1]:GetFmtGrade(),
        fmt_id2 = self.m_lCamps[2]:GetFmtId(),
        fmt_grade2 = self.m_lCamps[2]:GetFmtGrade(),
    })
end

function CWar:MarkWar(mInfo)
    if mInfo then
        local iWarId = self:GetWarId()
        local lActionIds = mInfo.action_id or {}
        for _, iActionId in pairs(lActionIds) do
            local oAction = loadaction.NewAction(iActionId, iWarId)
            if oAction then
                oAction:DoAction(mInfo)
                baseobj_delay_release(oAction)
            end
        end

        -- 喊话
        local mSpeekData = mInfo.speek
        local bSpeekEnable = mInfo.speek_enable
        if bSpeekEnable and mSpeekData then
            -- PS. SpeekCtrl可以进行定制，即修改（添加）此处的生成传入参数，令生成的执行对象是某玩法的定制对象
            local oSpeekCtrl = global.oSpeekMgr:GenWarSpeek(mSpeekData)
            self:BindWarSpeekCtrl(oSpeekCtrl)
        end
    end
    self:CalFormationEffect()
end

function CWar:BindWarSpeekCtrl(oSpeekCtrl)
    -- 喊话执行对象的生命周期改了，需要持续到战斗结束，故不能使用action
    self.m_oSpeekCtrl = oSpeekCtrl
    oSpeekCtrl:RegisterWar(self)
end

function CWar:GetWarSpeekCtrl()
    return self.m_oSpeekCtrl
end

function CWar:WarStart(mInfo)
    self:MarkWar(mInfo)

    self:TriggerEvent(gamedefines.EVENT.WAR_START, {war = self})

    self:BoutStart()
end

function CWar:IsWarEnd()
    return self.m_bWarEnd
end

function CWar:ForceWarEnd()
    self:WarEnd()
end

function CWar:WarEnd()
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")
    self:DelTimeCb("WarEnd")
    self.m_bWarEnd = true

    local mPartner = {}
    local mPlayer={}
    local mDie={}
    local mRoPlayer = {}
    local mRoDie = {}
    local mRoPartner = {}
    local mEscape = self.m_mEscape
    local mSummon  = {}

    for side , oCamp in ipairs(self.m_lCamps) do
        mPlayer[side]={}
        mDie[side]={}
        mPartner[side] = {}
        mRoPlayer[side] = {}
        mRoDie[side] = {}
        mRoPartner[side] = {}
        mSummon[side] = {}
        local mWarrior = self:GetWarriorList(side) or {}
        for _,oAction in pairs(mWarrior) do
            if oAction:IsPlayer() then
                if not oAction:IsDead() then
                    table.insert(mPlayer[side],oAction:GetPid())
                else
                    table.insert(mDie[side],oAction:GetPid())
                end
            elseif oAction:IsRoPlayer() then
                if not oAction:IsDead() then
                    table.insert(mRoPlayer[side],oAction:GetPid())
                else
                    table.insert(mRoDie[side],oAction:GetPid())
                end
            elseif oAction:IsPartner() then
                local iOwner = oAction:GetOwner()
                if oAction:IsDead() then
                    local mTmp = table_get_set_depth(mPartner[side], {iOwner, "die"})
                    table.insert(mTmp, oAction:GetPid())
                else
                    local mTmp = table_get_set_depth(mPartner[side], {iOwner, "live"})
                    table.insert(mTmp, oAction:GetPid())
                end
            elseif oAction:IsRoPartner() then
                local iOwner = oAction:GetOwner()
                if oAction:IsDead() then
                    local mTmp = table_get_set_depth(mRoPartner[side], {iOwner, "die"})
                    table.insert(mTmp, oAction:GetPid())
                else
                    local mTmp = table_get_set_depth(mRoPartner[side], {iOwner, "live"})
                    table.insert(mTmp, oAction:GetPid())
                end
            elseif oAction:IsSummon() then
                local iOwner = oAction:GetOwner()
                if iOwner then
                    if oAction:IsDead() then
                        mSummon[side]["die"] = mSummon[side]["die"] or {}
                        table.insert(mSummon[side]["die"],iOwner)
                    else
                        mSummon[side]["live"] = mSummon[side]["live"] or {}
                        table.insert(mSummon[side]["live"],iOwner)
                    end
                end
            end
        end
    end
            
    local l = table_key_list(self.m_mPlayers)
    for _, iPid in ipairs(l) do
        self:LeavePlayer(iPid)
    end
    local l = table_key_list(self.m_mObservers)
    for _, iPid in ipairs(l) do
        self:LeaveObserver(iPid)
    end
    local mArgs = {
        bout_out = self.m_bBoutOut,
        win_side = self.m_iWarResult,
        player=mPlayer,
        die=mDie,
        escape=mEscape,
        all_partner = mPartner,
        summon = mSummon,
        monster_info = self.m_oRecord:PackRecordMonster(),
        damage_info = self.m_oRecord:PackDamageInfo(),
        bout_cnt = self.m_iBout,
        war_video_data = self.m_oRecord:PackVideoData(),
        bulletbarrage_data = self.m_oBulletBarrage:PacketBulletBarrageData(),
        roplayer = mRoPlayer,
        rodie = mRoDie,
        ropartner = mRoPartner,
        war_back_args = self.m_mWarBackArgs,
        war_time = get_time() - self.m_iStartTime,
    }
    interactive.Send(".world", "war", "RemoteEvent", {event = "remote_war_end", data = {
        war_id = self:GetWarId(),
        war_info = mArgs,
    }})
end

function CWar:WarEndException()
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")
    self:DelTimeCb("WarEnd")

    local mPlayer = {}
    local mDie = {}
    for side, oCamp in ipairs(self.m_lCamps) do
        mPlayer[side] = {}
        local mWarrior = self:GetWarriorList(side) or {}
        for _,oAction in pairs(mWarrior) do
            if oAction:IsPlayer() then
                if not oAction:IsDead() then
                    table.insert(mPlayer[side], oAction:GetPid())
                else
                    table.insert(mDie[side], oAction:GetPid())
                end
            end
        end
    end

    local l = table_key_list(self.m_mPlayers)
    for _, iPid in ipairs(l) do
        self:LeavePlayer(iPid)
    end
    local l = table_key_list(self.m_mObservers)
    for _, iPid in ipairs(l) do
        self:LeaveObserver(iPid)
    end
    local mArgs = {
        player = mPlayer,
        die = mDie,
        war_exception = true,
    }
    interactive.Send(".world", "war", "RemoteEvent", {event = "remote_war_end_exception", data = {
        war_id = self:GetWarId(),
        war_info = mArgs,
    }})
end

function CWar:CurBout()
    return self.m_iBout
end

function CWar:CurAction()
    return self.m_iAction
end

function CWar:BoutStart()
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")

    self.m_iBout = self.m_iBout + 1
    self.m_iAction = 0
    self.m_mBoutRevive = {}

    self:ResetAnimationTime()
    self:ResetOperateTime()
    self.m_mBoutCmds = {}
    self.m_iBoutAICommand = false
    self:SetExtData("bout_start", get_time())

    self:TriggerEvent(gamedefines.EVENT.WAR_BOUT_PRE_START, {war = self})

    self.m_oBoutStatus:Set(gamedefines.WAR_BOUT_STATUS.OPERATE)
    local iOperateTime = 0
    if not self:IsWholeAIFight() then
        self:AddOperateTime(30*1000)
        iOperateTime = self:GetOperateTime()
    end

    self:SendAll("GS2CWarBoutStart", {
        war_id = self:GetWarId(),
        bout_id = self.m_iBout,
        left_time = math.floor(iOperateTime/1000),
    })

    safe_call(self.OnBoutStart, self)

    local iWarId = self:GetWarId()
    if not self:IsWholeAIFight() then
        self:DelTimeCb("CheckAutoPerform")
        self:AddTimeCb("CheckAutoPerform", 2*1000, function ()
            local oWar = global.oWarMgr:GetWar(iWarId)
            if oWar then
                oWar:CheckAutoPerform()
            end
        end)
        self:AddTimeCb("BoutProcess", iOperateTime + self:BaseOperateTime(), function ()
            local oWar = global.oWarMgr:GetWar(iWarId)
            if oWar then
                oWar:OnAIBoutProcess()
            end
        end)
    else
        self:AI()
        self:BoutProcess()
    end
end

function CWar:OnAIBoutProcess()
    self:OnOperateTimeOut()
    self:AI()
    self:BoutProcess()
end

function CWar:CheckAutoPerform()
    self:DelTimeCb("CheckAutoPerform")
    local lWarriors  = table_key_list(self.m_mWarriors)
    for _, iWid in ipairs(lWarriors) do
        local oAction = self:GetWarrior(iWid)
        if oAction and (oAction:IsPlayer() or oAction:IsSummon()) then
            if oAction:IsOpenFight() and not self:GetBoutCmd(iWid) then
                safe_call(oAction.AICommand, oAction)
            end
        end
    end
end

function CWar:OnOperateTimeOut()
    self.m_iBoutAICommand = true
    for k,_ in pairs(self.m_mWarriors) do
        local oAction = self:GetWarrior(k)
        if oAction:IsPlayer() and not oAction:IsOpenFight() and not self:GetBoutCmd(k) then
            oAction:StartAutoFight()
        end
    end
end

function CWar:BoutExecute()
    local oActionMgr = global.oActionMgr
    local lExecute = {}
    local lDead = {}
    local mNoExecute = {}

    for iWid, mCmd in pairs(self.m_mBoutCmds) do
        local oAction = self:GetWarrior(iWid)
        if oAction then
            local sCmd = mCmd.cmd
            local mData = mCmd.data
            oAction.m_bAction = false
            local mChangeCmd = oAction:CheckChangeCmd(mCmd, "order")
            if mChangeCmd then
                sCmd = mChangeCmd.cmd
                mData = mChangeCmd.data
            end
            if (oAction:HasKey("command_disable") and sCmd ~= "summon") or sCmd == "command_disable" then
                oAction.m_bAction = true
            elseif sCmd == "defense" then
                oAction:SetDefense(true)
                oAction.m_bAction = true
            elseif sCmd == "protect" then
                oAction:SetProtect(mData.select_wid)
                oAction.m_bAction = true
            else
                local fSpeed = oAction:GetSpeed()
                if oAction:QueryBoutArgs("speed") then
                    fSpeed = oAction:QueryBoutArgs("speed")
                end
                table.insert(lExecute, {iWid, mCmd, fSpeed})
            end
        end
    end

    local mOrder = {[1]=100, [5]=99, [4]=98, [6]=97, [3]=95, [7]=94, [2]= 90}
    -- local sort = function ()
    --     table.sort(lExecute, function (a, b)
    --         local iWid1, iWid2 = a[1], b[1]
    --         local o1 = self:GetWarrior(iWid1)
    --         local o2 = self:GetWarrior(iWid2)
    --         if o1:Status() == o2:Status() then
    --             if o1:IsAlive() and a[3] == b[3] then
    --                 if o1:IsPlayerLike() and o2:IsPlayerLike() then
    --                     return o1:GetData("exp", 0) < o2:GetData("exp", 0)
    --                 else
    --                     return mOrder[o1:Type()] < mOrder[o2:Type()]
    --                 end
    --             else
    --                 return a[3] < b[3]
    --             end
    --         else
    --             return o1:IsDead()
    --         end
    --     end)
    -- end
    local sort = function ()
        table.sort(lExecute, function (a, b)
            local iWid1, iWid2 = a[1], b[1]
            local o1 = self:GetWarrior(iWid1)
            local o2 = self:GetWarrior(iWid2)
            if a[3] == b[3] then
                if o1:IsPlayerLike() and o2:IsPlayerLike() then
                    return o1:GetData("exp", 0) < o2:GetData("exp", 0)
                else
                    return mOrder[o1:Type()] < mOrder[o2:Type()]
                end
            else
                return a[3] < b[3]
            end
        end)
    end

    sort()

    local iLen = #lExecute
    while iLen > 0 do
        local m = lExecute[iLen]
        local iWid, mCmd, fSpeed = table.unpack(m)
        local oAction = self:GetWarrior(iWid)
        self.m_iAction = self.m_iAction + 1
        if not oAction then
            mNoExecute[iWid] = mCmd
        elseif oAction:IsDead() then
            table.insert(lDead, {iWid, mCmd, fSpeed})
            mNoExecute[iWid] = mCmd
        else
            -- 行动前处理
            oAction:DoBeforeAct()
            self:TriggerEvent(gamedefines.EVENT.WAR_BEFORE_ACT, {war = self, actor = oAction, bout = self.m_iBout})

            oAction.m_bAction = true
            local sCmd = mCmd.cmd
            local mData = mCmd.data
            local mChangeCmd = oAction:CheckChangeCmd(mCmd, "use")
            if mChangeCmd then
                sCmd = mChangeCmd.cmd
                mData = mChangeCmd.data
            end
            if sCmd == "skill" then
                local lSelect = mData.select_wlist
                local iSkill = mData.skill_id
                local l = {}
                if lSelect then
                    for _, i in ipairs(lSelect) do
                        local o = self:GetWarrior(i)
                        if o then
                            table.insert(l, o)
                        end
                    end
                end
                if not oAction:PerformFunc(l,iSkill) then
                    oActionMgr:WarSkill(oAction, l, iSkill)
                end
            elseif sCmd == "normal_attack" then
                local iSelectWid = mData.select_wid
                local oSelect = self:GetWarrior(iSelectWid)
                if not oSelect or oSelect:IsDead() or not oSelect:IsVisible(oAction) then
                    local lVictim = oAction:GetEnemyList()
                    if #lVictim <= 0 then
                        oSelect = nil
                    else
                        oSelect = lVictim[math.random(#lVictim)]
                    end
                end
                if oSelect and not oSelect:IsDead() then
                    oActionMgr:WarNormalAttack(oAction, oSelect)
                end
            elseif sCmd == "escape" then
                self:TriggerEvent(gamedefines.EVENT.WAR_ESCAPE, {war = self, actor = oAction})
                oActionMgr:WarEscape(oAction)
            elseif sCmd == "summon" then
                oActionMgr:WarSummon(oAction,mData)
            elseif sCmd == "useitem" then
                local iSelectWid = mData.select_wid
                local iPid = mData.pid
                local mItemData = mData.itemdata
                local oSelect = self:GetWarrior(iSelectWid)
                oActionMgr:WarUseItem(oAction,oSelect,iPid,mItemData)
            end
        end

        table.remove(lExecute, iLen)

        for iPos=#lExecute,1,-1 do
            local m = lExecute[iPos] or {}
            local iWid,mCmd,fSpeed = table.unpack(m)
            local oAction = self:GetWarrior(iWid)
            if not oAction then
                table.remove(lExecute,iPos)
                mNoExecute[iWid] = mCmd
            end
        end
        local iAliveCount1 = self.m_lCamps[1]:GetAliveCount()
        local iAliveCount2 = self.m_lCamps[2]:GetAliveCount()
        if iAliveCount1<=0 or iAliveCount2<= 0 then
            break
        end

        --复活玩家开始行动
        if #lExecute == 0 then
            local mReviveSpeed = self:GetReviveSpeed()
            for _,mData in pairs(lDead) do
                local k,v,iSpeed = table.unpack(mData)
                local oDead = self:GetWarrior(k)
                if oDead and oDead:IsAlive() and not oDead.m_bAction then
                    iSpeed = mReviveSpeed[k] or iSpeed
                    table.insert(lExecute,{k,v,iSpeed})
                    mNoExecute[k] = nil
                end
            end
        end

        sort()
        iLen = #lExecute
    end

    safe_call(self.BoutNoExecute, self, mNoExecute)
end

function CWar:BoutNoExecute(mNoExecute)
    for _,mCmd in pairs(mNoExecute) do
        local sCmd = mCmd.cmd
        local mData = mCmd.data
        if sCmd == "useitem" then
            local iPid = mData.pid
            local mItemData = mData.itemdata or {}
            interactive.Send(".world", "war", "WarUseItem", {
                warid = self:GetWarId(),
                pid = iPid,
                itemid = mItemData.itemid,
                amount = 0,
            })
        end
    end
end

function CWar:BoutProcess()
    self:DelTimeCb("CheckAutoPerform")
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")
    self.m_oBoutStatus:Set(gamedefines.WAR_BOUT_STATUS.ANIMATION)
    self.m_iStartAnimationTime = get_time(true)

    safe_call(self.NewBout,self)
    safe_call(self.BoutExecute, self)

    local iAliveCount1 = self.m_lCamps[1]:GetAliveCount()
    local iAliveCount2 = self.m_lCamps[2]:GetAliveCount()
    if iAliveCount1 > 0 and iAliveCount2 > 0 then
        safe_call(self.OnBoutEnd, self)
    end
    local iAliveCount1 = self.m_lCamps[1]:GetAliveCount()
    local iAliveCount2 = self.m_lCamps[2]:GetAliveCount()

    self:SendAll("GS2CWarBoutEnd", {
        war_id = self:GetWarId(),
    })

    local iWarId = self:GetWarId()
    local iExtSec = 0
    if iAliveCount1 <= 0 then
        self.m_iWarResult = 2
        self:AddTimeCb("WarEnd",self:GetAnimationTime() + self:BaseAnimationTime(),function ()
            local oWar = global.oWarMgr:GetWar(iWarId)
            if oWar then
                oWar:WarEnd()
            end
        end)
    elseif iAliveCount2 <= 0 then
        self.m_iWarResult = 1
        self:AddTimeCb("WarEnd",self:GetAnimationTime() + self:BaseAnimationTime(),function ()
            local oWar = global.oWarMgr:GetWar(iWarId)
            if oWar then
                oWar:WarEnd()
            end
        end)
    elseif self.m_mBoutOutInfo and not self.m_iWarResult then
        local iBout = self.m_mBoutOutInfo.bout
        local iResult = self.m_mBoutOutInfo.result
        if iBout <= self.m_iBout then
            self.m_iWarResult = iResult
            self.m_bBoutOut = true
            self:AddTimeCb("WarEnd",self:GetAnimationTime() + self:BaseAnimationTime(),function ()
                local oWar = global.oWarMgr:GetWar(iWarId)
                if oWar then
                    oWar:WarEnd()
                end
            end)
        else
            --iExtSec = (iAliveCount1 + iAliveCount2) * 1500
            self.m_iMaxAnimationTime = self:GetAnimationTime() + self:BaseAnimationTime() + iExtSec
            self:AddTimeCb("BoutStart", self.m_iMaxAnimationTime, function ()
                local oWar = global.oWarMgr:GetWar(iWarId)
                if oWar then
                    oWar:BoutStart()
                end
            end)
        end
    else
        --iExtSec = (iAliveCount1 + iAliveCount2) * 1500
        self.m_iMaxAnimationTime = self:GetAnimationTime() + self:BaseAnimationTime() + iExtSec
        self:AddTimeCb("BoutStart", self.m_iMaxAnimationTime, function ()
            local oWar = global.oWarMgr:GetWar(iWarId)
            if oWar then
                oWar:BoutStart()
            end
        end)
    end
end

function CWar:OnWarStart()
    for _,v in ipairs(self.m_lCamps) do
        v:OnWarStart()
    end
    self:SendDebugMsg()
end

-- 角色下指令前
function CWar:OnBoutStart()
    local iBout = self.m_iBout
    if iBout == 1 then
        safe_call(self.OnWarStart,self)
    end
    for _, v in ipairs(self.m_lCamps) do
        v:OnBoutStart()
    end
    self:TriggerEvent(gamedefines.EVENT.WAR_BOUT_START, {war = self, bout = iBout})
end

-- 角色下指令后
function CWar:NewBout()
    for _,v in ipairs(self.m_lCamps) do
        v:NewBout()
    end
    self:AddDebugMsg(string.format("第%d回合",self.m_iBout),true)
end

function CWar:OnBoutEnd()
    for _, v in ipairs(self.m_lCamps) do
        v:OnBoutEnd()
    end
    self:TriggerEvent(gamedefines.EVENT.WAR_BOUT_END, {war = self, bout = self.m_iBout})
    self:SendDebugMsg()
    local iTime = self:GetAnimationTime() + self:BaseAnimationTime()
    self.m_oRecord:AddBoutTime(self.m_iBout,iTime)
end

function CWar:GetWarCommandExclude(iCamp)
    local mExclude={}
    for k, _ in pairs(self.m_mWatcher) do
        local o = self:GetWarrior(k)
        if not (o and o:GetCampId() == iCamp) then
            mExclude[k] = true
        end
    end
    for pid, oObserver in pairs(self.m_mObservers) do
        if  oObserver:GetCampId() ~= iCamp then
            mExclude[pid] = true
        end
    end
    return mExclude
end

function CWar:BroadWarCommand(iCamp,iSelectWid,sCmd)
    local mNet
    if not self.m_Appoint[iCamp] then
        self.m_Appoint[iCamp] = {}
    end
    if #self.m_Appoint[iCamp]>0 and (not sCmd or sCmd == "" ) then

        local pos
        for index,mInfo in ipairs(self.m_Appoint[iCamp])  do
            if mInfo.select_wid == iSelectWid then
                pos = index
                break
            end
        end
        if pos then
            table.remove(self.m_Appoint[iCamp],pos)
            local mExclude = self:GetWarCommandExclude(iCamp)
            mNet = {war_id = self.m_iWarId,op = 0,select_wid=iSelectWid}
            self:SendAll("GS2CWarCommandOP",mNet,mExclude)
        end
    end
    if sCmd then
        local op=1
        for _,mInfo in ipairs(self.m_Appoint[iCamp]) do
            if mInfo.select_wid == iSelectWid then
                op = 2
                mInfo.cmd = sCmd
                break
            end
        end
        if op == 1 then
            table.insert(self.m_Appoint[iCamp],{select_wid=iSelectWid,cmd=sCmd})
        end
        local mExclude = self:GetWarCommandExclude(iCamp)
        mNet = {war_id = self.m_iWarId,op = op,select_wid=iSelectWid,cmd = sCmd}
        self:SendAll("GS2CWarCommandOP",mNet,mExclude)
    end
end

function CWar:SendAll(sMessage, mData, mExclude)
    local sData = playersend.PackData(sMessage, mData)
    mExclude = mExclude or {}

    for k, _ in pairs(self.m_mWatcher) do
        if not mExclude[k] then
            local o = self:GetWarrior(k)
            if o then
                o:SendRaw(sData)
            end
        end
    end
    for pid, oObserver in pairs(self.m_mObservers) do
        if not mExclude[pid] then
            oObserver:SendRaw(sData)
        end
    end
    if self:IsWarRecord() then
        if sMessage == "GS2CWarBulletBarrage" then return end
        if sMessage == "GS2CWarCommand" then
            self.m_oRecord:AddBoutCmd(sMessage, mData)
        else
            self.m_oRecord:AddClientPacket(sMessage, mData)
        end
    end
end

function CWar:SetExtData(sKey, iValue)
    self.m_mExtData[sKey] = iValue
end

function CWar:GetExtData(sKey, rDefault)
    return self.m_mExtData[sKey] or rDefault
end

function CWar:AddDebugPlayer(oWarrior)
    self.m_mDebugPlayer[oWarrior:GetPid()] = oWarrior:GetWid()
end

function CWar:DelDebugPlayer(oWarrior)
    self.m_mDebugPlayer[oWarrior:GetPid()] = nil
end

function CWar:AddDebugMsg(sMsg, bNew)
    if bNew and table_count(self.m_mDebugMsg) then
        local sMessage = table.concat(self.m_mDebugMsg,",")
        table.insert(self.m_mDebugMsgQueue, sMessage)
        self.m_mDebugMsg = {}
    end
    if sMsg and sMsg ~= "" then
        table.insert(self.m_mDebugMsg, sMsg)
    end
end

function CWar:SendDebugMsg()
    if table_count(self.m_mDebugMsg) then
        local sMsg = table.concat(self.m_mDebugMsg,",")
        table.insert(self.m_mDebugMsgQueue, sMsg)
        self.m_mDebugMsg = {}
    end
    for _, sMessage in pairs(self.m_mDebugMsgQueue) do
        local mData = {
            type = gamedefines.CHANNEL_TYPE.MSG_TYPE,
            content = sMessage,
        }
        local sData = playersend.PackData("GS2CConsumeMsg", mData)
        for pid, iWid in pairs(self.m_mDebugPlayer) do
            local o = self:GetWarrior(iWid)
            if o then
                o:SendRaw(sData)
            end
        end
    end
    self.m_mDebugMsgQueue = {}
end

function CWar:SetWarBackArgs(sKey, rVal)
    self.m_mWarBackArgs[sKey] = rVal
end

function CWar:AddWarBackArgs(sKey, iVal)
    if not self.m_mWarBackArgs[sKey] then
        self.m_mWarBackArgs[sKey] = 0
    end
    self.m_mWarBackArgs[sKey] = self.m_mWarBackArgs[sKey] + iVal
end

function CWar:GetWarBackArgs(sKey)
    return self.m_mWarBackArgs[sKey]
end

