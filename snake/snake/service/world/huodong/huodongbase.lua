--import module
local global  = require "global"
local extend = require "base.extend"
local interactive = require "base.interactive"
local record = require "public.record"
local res = require "base.res"

local templ = import(service_path("templ"))
local npcobj = import(service_path("npc.npcobj"))
local effectobj = import(service_path("effect.effectobj"))
local rewardmonitor = import(service_path("rewardmonitor"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sName = "huodong"
CHuodong.m_sTempName = "神秘活动"
inherit(CHuodong, templ.CTempl)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    o.m_iScheduleID = nil
    o.m_sName = sHuodongName
    o.m_mNpcList = {}
    o.m_mEffectList = {}
    o.m_mSceneList = {}
    return o
end

function CHuodong:Init()
    -- body
end

function CHuodong:Release()
    self.m_mNpcList = {}
    self.m_mEffectList = {}
    self.m_mSceneList = {}
    if self.m_oRewardMonitor then
        baseobj_safe_release(self.m_oRewardMonitor)
        self.m_oRewardMonitor = nil
    end
    super(CHuodong).Release(self)
end

-- @Override
function CHuodong:GetCbSelfGetter()
    local sHuodongName = self.m_sName
    return function()
        return global.oHuodongMgr:GetHuodong(sHuodongName)
    end
end

function CHuodong:IsLoaded()
    if not self:NeedSave() then
        return true
    end
    return super(CHuodong).IsLoaded(self)
end

function CHuodong:IsLoadedSuccess()
    if not self:NeedSave() then
        return true
    end
    return super(CHuodong).IsLoadedSuccess(self)
end

function CHuodong:NeedSave()
    return false
end

function CHuodong:Save()
    -- body
end

function CHuodong:Load(mData)
    -- body
end

function CHuodong:MergeFrom(mFromData)
    return false, "merge function is not implemented"
end

function CHuodong:LoadDb()
    if not self:NeedSave() then return end
    local mInfo = {
        module = "huodongdb",
        cmd = "LoadHuoDong",
        cond = {name = self.m_sName},
    }
    gamedb.LoadDb(self.m_sName, "common", "DbOperate", mInfo, function (mRecord, mData)
        if not self:IsLoaded(self) then
            local m = mData.data
            self:Load(m)
            self:OnLoaded()
        end
    end)
end

function CHuodong:SaveDb()
    if not self:NeedSave() then return end
    if not self:IsLoaded() then return end
    if is_release(self) then return end
    if not self:IsDirty() then return end

    local mInfo = {
        module = "huodongdb",
        cmd = "SaveHuoDong",
        cond = {name = self.m_sName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb(self.m_sName, "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CHuodong:ConfigSaveFunc()
    local sName = self.m_sName
    self:ApplySave(function ()
        local oHuodongMgr = global.oHuodongMgr
        local obj = oHuodongMgr:GetHuodong(sName)
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("huodong %s save err: no obj", sName)
        end
    end)
end

function CHuodong:_CheckSaveDb()
    if not self:NeedSave() then return end
    assert(not is_release(self), string.format("huodong %s save err: release", self.m_sName))
    assert(self:IsLoaded(), string.format("huodong %s save err: loading", self.m_sName))
    self:SaveDb()
end

function CHuodong:ScheduleID()
    return self.m_iScheduleID
end

function CHuodong:AddSchedule(oPlayer)
    oPlayer.m_oScheduleCtrl:Add(self:ScheduleID())
end

function CHuodong:GetSchedule(oPlayer)
    return oPlayer.m_oScheduleCtrl:GetDoneTimes(self:ScheduleID())
end

function CHuodong:NewHour(mNow)
    -- body
end

function CHuodong:NewDay(mNow)
    --
end

function CHuodong:ReplaceStart(mReplace)
end

function CHuodong:IsOpenDay(iTime)   --限时活动接口
    return false
end

function CHuodong:OnServerStartEnd()
end

function CHuodong:OnUpgrade(oPlayer, iFromGrade, iGrade)
end

function CHuodong:AddUpgradeEvent(oPlayer)
    local _OnUpgrade = function(iEventType, mData)
        local oUpPlayer = mData.player
        local iFromGrade = mData.from
        local iGrade = mData.player_grade
        self:OnUpgrade(oUpPlayer, iFromGrade, iGrade)
    end
    oPlayer:AddEvent(self, gamedefines.EVENT.ON_UPGRADE, _OnUpgrade)
end

function CHuodong:DelUpgradeEvent(oPlayer)
    oPlayer:DelEvent(self, gamedefines.EVENT.ON_UPGRADE)
end

function CHuodong:OnLogin(oPlayer,bReEnter)
    -- body
end

function CHuodong:OnLogout(oPlayer)
    -- body
end

function CHuodong:GetStartTime()
    local iScheduleId = self:ScheduleID()
    local sTime = table_get_depth(res, {"daobiao", "schedule", "schedule", iScheduleId, "activetime"})
    return sTime or ""
end

function CHuodong:GetTollGateData(iFight)
    local mData = res["daobiao"]["fight"][self.m_sName]["tollgate"][iFight]
     assert(mData,string.format("CHuodong GetTollGateData err: %s %d", self.m_sName, iFight))
    return mData
end

function CHuodong:GetMonsterData(iMonsterIdx)
    local mData = res["daobiao"]["fight"][self.m_sName]["monster"][iMonsterIdx]
    assert(mData,string.format("CHuodong GetMonsterData err: %s %d", self.m_sName, iMonsterIdx))
    return mData
end

function CHuodong:GetEventData(iEvent)
    if not iEvent then return {} end

    local mData = res["daobiao"]["huodong"][self.m_sName]["event"][iEvent]
    assert(mData,string.format("CHuodong GetEventData err: %s %d", self.m_sName, iEvent))
    return mData
end

function CHuodong:GetTempNpcData(iTempNpc)
    local mData = res["daobiao"]["huodong"][self.m_sName]["npc"][iTempNpc]
    assert(mData,string.format("CHuodong GetTempNpcData err: %s %d", self.m_sName, iTempNpc))
    return mData
end

function CHuodong:GetTempSceneEffectData(iTemplId)
    local mData = res["daobiao"]["huodong"][self.m_sName]["scene_effect"][iTemplId]
    assert(mData, string.format("CHuodong GetTempSceneEffectData err: %s %d", self.m_sName, iTemplId))
    return mData
end

function CHuodong:GetTextData(iText)
    local oToolMgr = global.oToolMgr
    return oToolMgr:GetTextData(iText, {"huodong", self.m_sName})
end

function CHuodong:GetRewardData(iReward)
    local mData = res["daobiao"]["reward"][self.m_sName]["reward"][iReward]
    assert(mData,string.format("CHuodong:GetRewardData err:%s %d", self.m_sName, iReward))
    return mData
end

function CHuodong:GetItemRewardData(iItemReward)
    local mData = res["daobiao"]["reward"][self.m_sName]["itemreward"][iItemReward]
    assert(mData,string.format("CHuodong:GetItemRewardData err:%s %d", self.m_sName, iItemReward))
    return mData
end

function CHuodong:DoScript(pid,npcobj,s,mArgs)
    if type(s) ~= "table" then
        return
    end
    for _,ss in pairs(s) do
        self:DoScript2(pid,npcobj,ss, mArgs)
    end
end

function CHuodong:DoScript2(pid,npcobj,s,mArgs)
    local sCmd = string.match(s, "^([$%a]+)")
    if sCmd then
        local sArgs = string.sub(s, #sCmd+1, -1)

        if sCmd == "CN" then
            local npctype = tonumber(sArgs)
            -- PS: 如果子类需要创建镜像npc，需要传oPlayer
            self:CreateTempNpc(npctype, pid)
            return true
        elseif sCmd == "E" then
            local npctype,iEvent = string.match(sArgs,"(.+):(.+)")
            npctype = tonumber(npctype)
            iEvent = tonumber(iEvent)
            self:SetEvent(npctype, iEvent)
            return true
        elseif sCmd == "D" then
            local iText = tonumber(sArgs)
            if not iText then
                return
            end
            local sText = self:GetTextData(iText)
            if npcobj:InWar() then
                local sWarText= self:GetNpcInWarText(npcobj)
                if sWarText then
                    sText = sWarText
                end
            end
            if sText then
                self:SayText(pid,npcobj,sText)
            end
            return true
        elseif sCmd == "TD" then
            local iText = tonumber(sArgs)
            if not iText then return end

            local sText = self:GetTextData(iText)
            if npcobj:InWar() then
                local sWarText= self:GetNpcInWarText(npcobj)
                if sWarText then
                    sText = sWarText
                end
            end
            if sText then
                self:SayText(pid,npcobj,sText,nil,nil,sCmd)
            end
            return true
        elseif sCmd == "RN" then
            self:RemoveTempNpc(npcobj)
            return true
        end
    end
    if self:OtherScript(pid,npcobj,s,mArgs) then
        return true
    end
    super(CHuodong).DoScript2(self,pid,npcobj,s,mArgs)
end

function CHuodong:OtherScript(pid,npcobj,s,mArgs)
    -- body
end

function CHuodong:GetNpcName(iTempNpc,sDefaultName)
    return sDefaultName or "未知"
end

-- @param oPlayer: <nil/object>如果需要创建玩家镜像，oPlayer必填
function CHuodong:PacketNpcInfo(iTempNpc, oPlayer)
    local mData = self:GetTempNpcData(iTempNpc)
    local sName = self:GetNpcName(iTempNpc,mData["name"])

    local mPosInfo = {
        x = mData["x"],
        y = mData["y"],
        z = mData["z"],
        face_x = mData["face_x"] or 0,
        face_y = mData["face_y"] or 0,
        face_z = mData["face_z"] or 0,
    }
    local mArgs = {
        type = mData["id"],
        name = sName,
        title = mData["title"],
        map_id = mData["mapid"],
        pos_info = mPosInfo,
        event = mData["event"] or 0,
        npc_id = iTempNpc,
        func_group = self:NpcFuncGroup("huodong"),
    }
    local iEffectId = mData["effect_id"]
    if iEffectId and iEffectId > 0 then
        mArgs.effect_id = iEffectId
    else
        mArgs.model_info = self:PackModelInfo(mData, oPlayer)
        mArgs.xunluo_id = mData["xunluo_id"]
        mArgs.grade = mData["grade"]
    end
    return mArgs
end

-- @Overrideable
function CHuodong:MakeTempNpc(iTempNpc)
    local mArgs = self:PacketNpcInfo(iTempNpc, nil)
    local oTempNpc = NewHDNpc(mArgs)
    global.oNpcMgr:AddObject(oTempNpc)
    return oTempNpc
end

-- @Overrideable
function CHuodong:CreateTempNpc(iTempNpc, pid)
    local oTempNpc = self:MakeTempNpc(iTempNpc)
    oTempNpc.m_sHuodong = self.m_sName
    self.m_mNpcList[oTempNpc.m_ID] = oTempNpc
    return oTempNpc
end

function CHuodong:Npc_Enter_Map(oTempNpc)
    local oSceneMgr = global.oSceneMgr
    local mScene = oSceneMgr:GetSceneListByMap(oTempNpc.m_iMapid)
    local oNpc = oTempNpc
    for k, oScene in ipairs(mScene) do
        if k ~= 1 then
            oNpc = self:CreateTempNpc(oTempNpc:Type())
        end
        oNpc.m_iMapid = oScene:MapId()
        oNpc:SetScene(oScene:GetSceneId())
        oScene:EnterNpc(oNpc)
    end
end

function CHuodong:Npc_Enter_Scene(oTempNpc, iScene)
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oTempNpc.m_iMapid = oScene:MapId()
        oTempNpc:SetScene(iScene)
        oScene:EnterNpc(oTempNpc)
    end
end

function CHuodong:GetNpcObj(nid)
    return self.m_mNpcList[nid]
end

function CHuodong:GetNpcListByMap(iMap)
    local lNpcList = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:MapId() == iMap then
            table.insert(lNpcList, oNpc)
        end
    end
    return lNpcList
end

function CHuodong:GetNpcListByScene(iScene)
    local lNpcList = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc.m_Scene == iScene then
            table.insert(lNpcList, oNpc)
        end
    end
    return lNpcList
end

function CHuodong:RemoveTempNpc(oNpc)
    local npcid = oNpc.m_ID
    local iScene = oNpc.m_Scene
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene and not oNpc:IsNotEnterScene() then
        oScene:RemoveSceneNpc(npcid)
    end
    self.m_mNpcList[npcid] = nil
    global.oNpcMgr:RemoveObject(npcid)
    baseobj_delay_release(oNpc)
end

function CHuodong:RemoveTempNpcByType(npctype)
    local lNpcIdxs = {}
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:Type() == npctype then
            table.insert(lNpcIdxs, oNpc)
        end
    end
    for nid, oNpc in pairs(lNpcIdxs) do
        self:RemoveTempNpc(oNpc)
    end
end

function CHuodong:SetEvent(npctype, iEvent)
    for nid, oNpc in pairs(self.m_mNpcList) do
        if oNpc:Type() == npctype then
            oNpc.SetEvent(iEvent)
        end
    end
end

function CHuodong:GetEvent(nid)
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        return
    end
    return npcobj.m_iEvent
end

function CHuodong:SayText(pid,npcobj,sText,func,iTime,sCmd)
    local nid = npcobj.m_ID
    if func then
        if sCmd and sCmd == "TD" then
            npcobj:TeamSayRespond(pid,sText,nil,func,nil,nil,nil,iTime)
        else
            npcobj:SayRespond(pid,sText,nil,func,nil,nil,nil,iTime)
        end
    else
        local mEvent = self:GetEventData(npcobj.m_iEvent)
        local mAnswer = mEvent["answer"]
        if not mAnswer or table_count(mAnswer) <= 0 then
            if sCmd and sCmd == "TD" then
                npcobj:TeamSay(pid,sText,nil,nil,nil,iTime)
            else
                npcobj:Say(pid,sText,nil,nil,nil,iTime)
            end
        else
            local func = function (oPlayer,mData)
                local iAnswer = mData["answer"]
                self:RespondLook(oPlayer, nid, iAnswer)
            end
            if sCmd and sCmd == "TD" then
                npcobj:TeamSayRespond(pid,sText,nil,func,nil,nil,nil,iTime)
            else
                npcobj:SayRespond(pid,sText,nil,func,nil,nil,nil,iTime)
            end
        end
    end
end

function CHuodong:do_look(oPlayer, npcobj)
    if not npcobj or not npcobj.m_iEvent then
        return
    end
    local mEvent = self:GetEventData(npcobj.m_iEvent)
    if mEvent and mEvent["look"] then
        self:DoScript(oPlayer:GetPid(),npcobj,mEvent["look"])
    end
end

function CHuodong:RespondLook(oPlayer, nid, iAnswer)
    local npcobj = self:GetNpcObj(nid)
    if not npcobj then
        return
    end
    if not self:ValidMemberRespond(oPlayer, npcobj, iAnswer) then
        return
    end
    local mEvent = self:GetEventData(npcobj.m_iEvent)
    if not mEvent then
        return
    end
    local mAnswer = mEvent["answer"]
    if not mAnswer or not next(mAnswer) then
        return
    end
    local s = mAnswer[iAnswer] or ""
    if self:CheckAnswer(oPlayer, npcobj, iAnswer) then
        self:DoScript2(oPlayer:GetPid(),npcobj,s)
    end
end

function CHuodong:ValidMemberRespond(oPlayer, npcobj, iAnswer)
    if oPlayer:IsSingle() then
        return true
    elseif oPlayer:IsTeamLeader() then
        return true
    end
    return false
end

function CHuodong:CheckAnswer(oPlayer, npcobj, iAnswer)
    return true
end


function CHuodong:PacketEffectInfo(iTemplId)
    local mData = self:GetTempSceneEffectData(iTemplId)
    local mPosInfo = {
        x = mData.x,
        y = mData.y,
        z = mData.z,
    }
    local iEffId = mData.effect_id
    local mArgs = {
        type = iTemplId,
        name = mData.name,
        pos_info = mPosInfo,
    }
    return iEffId, mArgs
end

-- @Overrideable
function CHuodong:MakeTempEffect(iTemplId)
    local iEffectId, mArgs = self:PacketEffectInfo(iTemplId)
    local oTempEffect = NewHDEffect(iEffectId, mArgs)
    return oTempEffect
end

-- @Overrideable
function CHuodong:CreateTempEffect(iTemplId)
    local oTempEffect = self:MakeTempEffect(iTemplId)
    self.m_mEffectList[oTempEffect:ID()] = oTempEffect
    return oTempEffect
end

function CHuodong:EffectEnterScene(oEffect, iScene, mPosInfo)
    if not iScene then
        return
    end
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oEffect.m_mPosInfo = mPosInfo
        oEffect:SetScene(iScene)
        oScene:EnterEffect(oEffect)
    end
end

function CHuodong:RemoveTempEffect(oEffect)
    local iObjId = oEffect:ID()
    local iScene = oEffect:GetScene()
    local oSceneMgr = global.oSceneMgr
    local oScene = oSceneMgr:GetScene(iScene)
    if oScene then
        oScene:RemoveSceneEffect(iObjId)
    end
    self.m_mEffectList[iObjId] = nil
    baseobj_delay_release(oEffect)
end

function CHuodong:RemoveTempEffectByType(iTypeId)
    local lEffectIdxs = {}
    for nid, oEffect in pairs(self.m_mEffectList) do
        if oEffect:Type() == iTypeId then
            table.insert(lEffectIdxs, oEffect)
        end
    end
    for nid, oEffect in pairs(lEffectIdxs) do
        self:RemoveTempEffect(oEffect)
    end
end

function CHuodong:TestOp(sOrder, mArgs)
end

function CHuodong:GetNpcInWarText(npcobj)
    return nil
end

function CHuodong:CheckRewardMonitor(iPid, iRewardId, iCnt, mArgs)
    if self.m_oRewardMonitor then
        if not self.m_oRewardMonitor:CheckRewardGroup(iPid, iRewardId, iCnt, mArgs) then
            return false
        end
    end
    return true
end

function CHuodong:TryStartRewardMonitor()
    if not self.m_oRewardMonitor then
        local lUrl = {"reward", self.m_sName}
        local o = rewardmonitor.NewMonitor(self.m_sName, lUrl)
        self.m_oRewardMonitor = o
    end
end

function CHuodong:TryStopRewardMonitor()
    if self.m_oRewardMonitor then
        self.m_oRewardMonitor:ClearRecordInfo()
    end
end

function CHuodong:Notify(iPid, iChat, mReplace)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = self:GetTextData(iChat)
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    oNotifyMgr:Notify(iPid, sMsg)
end

function CHuodong:SysAnnounce(iChat, mReplace)
    local mInfo = res["daobiao"]["chuanwen"][iChat]
    if not mInfo then return end

    local sMsg, iHorse = mInfo.content, mInfo.horse_race
    if mReplace then
        sMsg = global.oToolMgr:FormatColorString(sMsg, mReplace)
    end
    global.oChatMgr:HandleSysChat(sMsg, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, iHorse)
end

function CHuodong:RegisterHD(mInfo, bClose)
    return false, "not implemented"
end

function CHuodong:IsHuodongOpen()
    return false
end

function CHuodong:OpenHDSchedule(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local iSchedule = self:ScheduleID()
        oPlayer:Send("GS2COpenScheduleUI", {schedule_id = iSchedule})
    end
end

---------------------------ks huodong-------------------------------------
function CHuodong:IsKSGameStart()
    return false
end

function CHuodong:ValidJoinKSGame(oPlayer)
    return false
end

function CHuodong:JoinKSGame(oPlayer)
    assert(false, string.format("CHuodong:JoinKSGame--not implemented--"))
end

function CHuodong:GetKSNameKey()
    return string.format("%s_ks", self.m_sName)
end

---------------------------------
CHDNpc = {}
CHDNpc.__index = CHDNpc
inherit(CHDNpc, npcobj.CNpc)

function CHDNpc:New(mArgs)
    local o = super(CHDNpc).New(self)
    o:Init(mArgs)
    return o
end

function CHDNpc:Init(mArgs)
    -- self:InitObject()
    local mArgs = mArgs or {}

    self.m_iType = mArgs["type"]
    self.m_sName = mArgs["name"] or ""
    self.m_sTitle = mArgs["title"] or ""
    self.m_iMapid = mArgs["map_id"] or 0
    self.m_mModel = mArgs["model_info"] or {}
    self.m_mPosInfo = mArgs["pos_info"] or {}
    self.m_iGrade = mArgs["grade"] or 1
    self.m_iEvent = mArgs["event"] or 0
    self.m_iXunLuoID = mArgs["xunluo_id"] or 0
    self.m_iNpcId = mArgs["npc_id"] or 0
    self.m_sFuncGroup = mArgs["func_group"]
end

function CHDNpc:NpcID()
    return self.m_iNpcId
end

function CHDNpc:SetXunLuoID(xunluoid)
    self.m_iXunLuoID = xunluoid
end

function CHDNpc:GetTitle()
    return self.m_sTitle
end

function CHDNpc:SetMigrateInfo(info)
    self.m_mMigrateInfo = info
end

function CHDNpc:GetMoveAIInfo(sceneid)
    if self.m_iXunLuoID and self.m_iXunLuoID > 0 then
        return {
            aitype = "xunluo",
            aiargs = {
                xunluoid=self.m_iXunLuoID,
            },
        }
    elseif self.m_mMigrateInfo and self.m_mMigrateInfo[sceneid] then
        local info = self.m_mMigrateInfo[sceneid]
        return {
            aitype = "migrate",
            aiargs = {
                routeline = info.routeline,
                nextsc = info.nextsc,
                nextpos = info.nextpos,
                interval = info.interval,
            },
        }
    end
end

function CHDNpc:SetEvent(iEvent)
    self.m_iEvent = iEvent
end

function CHDNpc:do_look(oPlayer)
    if self.m_sHuodong then
        local oHuodong = global.oHuodongMgr:GetHuodong(self.m_sHuodong)
        oHuodong:do_look(oPlayer, self)
    end
end

function CHDNpc:IsNotEnterScene( )
    return self.m_bEnterScene
end

function CHDNpc:IsSameMap(oScene)
    if self:IsNotEnterScene() then
        if oScene and oScene:MapId()==self:MapId() then
            return true 
        end
    end
    return super(CHDNpc).IsSameMap(self, oScene)
end

---------------------------------
CHDEffect = {}
CHDEffect.__index = CHDEffect
inherit(CHDEffect, effectobj.CSceneEffect)

function CHDEffect:New(iEffectId, mInfo)
    local o = super(CHDEffect).New(self, iEffectId)
    o:Init(mInfo)
    return o
end

--------------------------
function NewHDNpc(mArgs)
    return CHDNpc:New(mArgs)
end

function NewHDEffect(iEffectId, mArgs)
    assert(iEffectId and iEffectId > 0)
    return CHDEffect:New(iEffectId, mArgs)
end
