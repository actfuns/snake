--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local interactive = require "base.interactive"
local res = require "base.res"
local geometry = require "base.geometry"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local analylog = import(lualib_path("public.analylog"))

function NewWarMgr(...)
    local o = CWarMgr:New(...)
    return o
end

function NewWar(...)
    local o = CWar:New(...)
    return o
end


CWarMgr = {}
CWarMgr.__index = CWarMgr
inherit(CWarMgr, logic_base_cls())

function CWarMgr:New(lWarRemote)
    local o = super(CWarMgr).New(self)
    o.m_iDispatchId = 0
    o.m_mWars = {}
    o.m_iSelectHash = 1
    o.m_lWarRemote = lWarRemote
    o.m_mRecordUseItem = {}
    return o
end

function CWarMgr:Release()
    for _, v in pairs(self.m_mWars) do
        baseobj_safe_release(v)
    end
    self.m_mWars = {}
    super(CWarMgr).Release(self)
end

function CWarMgr:DispatchWarId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    if self.m_iDispatchId > 10000000 then
        self.m_iDispatchId = 1
    end
    return self.m_iDispatchId
end

function CWarMgr:SelectRemoteWar()
    local iSel = self.m_iSelectHash
    if iSel >= #self.m_lWarRemote then
        self.m_iSelectHash = 1
    else
        self.m_iSelectHash = iSel + 1
    end
    return self.m_lWarRemote[iSel]
end

function CWarMgr:CreateWar(iWarType, iSysType, mInfo)
    local id = self:DispatchWarId()
    local oWar = NewWar(id, iWarType, iSysType, mInfo)
    oWar:ConfirmRemote()
    self.m_mWars[id] = oWar
    return oWar
end

function CWarMgr:GetWar(id)
    return self.m_mWars[id]
end

function CWarMgr:RemoveWar(id)
    local oWar = self.m_mWars[id]
    if oWar then
        baseobj_delay_release(oWar)
        self.m_mWars[id] = nil
    end
end

function CWarMgr:OnDisconnected(oPlayer)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        oNowWar:NotifyDisconnected(oPlayer)
    end
end

function CWarMgr:OnLogout(oPlayer)
    self:LeaveWar(oPlayer, true)
end

function CWarMgr:OnLogin(oPlayer, bReEnter)
    if bReEnter then
        self:ReEnterWar(oPlayer)
    end
end

function CWarMgr:ReEnterWar(oPlayer)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        oNowWar:ReEnterPlayer(oPlayer)
    end
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:LeaveWar(oPlayer, bForce)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if not oNowWar then
        return {errcode = gamedefines.ERRCODE.ok}
    end
    if not bForce then
        if not oNowWar:VaildLeave(oPlayer) then
            return {errcode = gamedefines.ERRCODE.common}
        end
    end
    oNowWar:LeavePlayer(oPlayer)
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:TeamLeaveObserverWar(oPlayer, bForce)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if not oNowWar then
        return {errcode = gamedefines.ERRCODE.ok}
    end
    local mMem = oPlayer:GetTeamMember() or {oPlayer:GetPid()}
    if not bForce then
        for _, pid in ipairs(mMem) do
            local oMem = global.oWorldMgr:GetOnlinePlayerByPid(pid)
            if not oMem or not oNowWar:VaildLeave(oPlayer) then
                return {errcode = gamedefines.ERRCODE.common}
            end
        end
    end

    for _, pid in ipairs(mMem) do
        local oMem = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        oNowWar:LeavePlayer(oMem)
    end
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:ObserverEnterWar(oPlayer, iWarId, mArgs)
    local oNewWar = self:GetWar(iWarId)
    assert(oNewWar, string.format("ObserverEnterWar err %d", iWarId))
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar then
        return {errcode = gamedefines.ERRCODE.common}
    end

    if oNewWar then
        oNewWar:EnterObserver(oPlayer, mArgs)
    end
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:TeamObserverEnterWar(oPlayer, iWarId, mArgs)
    local oNewWar = self:GetWar(iWarId)
    assert(oNewWar, string.format("EnterWar error %d", iWarId))

    local oWorldMgr = global.oWorldMgr
    local mMem = oPlayer:GetTeamMember()
    local mPlayer = {}
    for _,pid in ipairs(mMem) do
        local oMemPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        table.insert(mPlayer,oMemPlayer)
    end

    for _,oMemPlayer in pairs(mPlayer) do
        local oNowWar = oMemPlayer.m_oActiveCtrl:GetNowWar()
        if oNowWar then
            return {errcode = gamedefines.ERRCODE.common}
        end
    end
    for _, oMemPlayer in pairs(mPlayer) do
        oNewWar:EnterObserver(oMemPlayer, mArgs)
    end
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:EnterWar(oPlayer, iWarId, mInfo, bForce, iPartnerLimit)
    local oNewWar = self:GetWar(iWarId)
    assert(oNewWar, string.format("EnterWar error %d", iWarId))
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()

    if not bForce then
        if oNowWar and not oNowWar:VaildLeave(oPlayer) then
            return {errcode = gamedefines.ERRCODE.common}
        end
        if not oNewWar:VaildEnter(oPlayer) then
            return {errcode = gamedefines.ERRCODE.common}
        end
    end

    local mFmtInfo = oPlayer:PackWarFormationInfo(iPartnerLimit)
    oNewWar:PrepareCamp(mInfo.camp_id, {fmtinfo=mFmtInfo})

    if oNowWar then
        oNowWar:LeavePlayer(oPlayer)
    end
    oNewWar:EnterPlayer(oPlayer, mInfo)
    iPartnerLimit = iPartnerLimit or 4
    oNewWar:EnterPartner(oPlayer, mInfo, iPartnerLimit)

    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:TeamEnterWar(oPlayer,iWarId,mInfo,bForce, iPartnerLimit)
    local oNewWar = self:GetWar(iWarId)
    assert(oNewWar, string.format("EnterWar error %d", iWarId))

    local oWorldMgr = global.oWorldMgr
    local mMem = oPlayer:GetTeamMember()
    local mPlayer = {}
    for _,pid in ipairs(mMem) do
        local oMemPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        table.insert(mPlayer,oMemPlayer)
    end

    if not bForce then
        for _,oMemPlayer in pairs(mPlayer) do
            local oNowWar = oMemPlayer.m_oActiveCtrl:GetNowWar()
            if oNowWar and not oNowWar:VaildLeave(oMemPlayer) then
                return {errcode = gamedefines.ERRCODE.common}
            end
            if not oNewWar:VaildEnter(oMemPlayer) then
                return {errcode = gamedefines.ERRCODE.common}
            end
        end
    end

    local mFmtInfo = oPlayer:PackWarFormationInfo(iPartnerLimit)
    oNewWar:PrepareCamp(mInfo.camp_id, {fmtinfo=mFmtInfo})

    for _,oMemPlayer in pairs(mPlayer) do
        local oNowWar = oMemPlayer.m_oActiveCtrl:GetNowWar()
        if oNowWar then
            oNowWar:LeavePlayer(oMemPlayer)
        end
        oNewWar:EnterPlayer(oMemPlayer,mInfo)
    end
    iPartnerLimit = iPartnerLimit or 4
    oNewWar:EnterPartner(oPlayer, mInfo, math.min(iPartnerLimit, 5-table_count(mPlayer)))
    return {errcode = gamedefines.ERRCODE.ok}
end

function CWarMgr:PrepareWar(iWarId, mInfo, mConfig)
    local oWar = self:GetWar(iWarId)
    if oWar then
        oWar:WarPrepare(mInfo, mConfig)
    end
end

function CWarMgr:StartWar(iWarId, mInfo)
    local oWar = self:GetWar(iWarId)
    if oWar then
        oWar:WarStart(mInfo)
    end
end

function CWarMgr:RemoteEvent(sEvent, mData)
    if sEvent == "remote_leave_player" then
        local iWarId = mData.war_id
        local iPid = mData.pid
        local bEscape = mData.escape
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
            if oNowWar and oNowWar:GetWarId() == iWarId then
                oNowWar:RemoteLeavePlayer(oPlayer,bEscape)
                self:OnLeaveWar(oPlayer,mData,oNowWar)
            end
        end
    elseif sEvent == "remote_war_end" then
        local iWarId = mData.war_id
        local mArgs = mData.war_info
        mArgs.warid = iWarId
        local mVideo = mArgs.war_video_data
        if mVideo then
            local mBulletBarrage = mArgs.bulletbarrage_data
            local oVideoMgr = global.oVideoMgr
            oVideoMgr:AddWarVideo(mVideo, function (oVideo)
                local iVideoId = oVideo:GetVideoId()
                local iType = oVideo:GetWarType()
                global.oBulletBarrageMgr:AddBulletBarrageObj(iVideoId, iType, mBulletBarrage)
            end)
        end

        local oWar = self:GetWar(iWarId)
        if oWar then
            oWar:WarEnd(mArgs)
        end
        self:RemoveWar(iWarId)
    elseif sEvent == "remote_leave_observer" then
        local iWarId = mData.war_id
        local iPid = mData.pid
        local oWorldMgr = global.oWorldMgr
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oPlayer then
            local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
            if oNowWar and oNowWar:GetWarId() == iWarId then
                oNowWar:RemoteLeaveObserver(oPlayer)
            end
        end
    elseif sEvent == "remote_end_warvideo" then
        local iWarId = mData.war_id
        local mArgs = mData.war_info
        local oWar = self:GetWar(iWarId)
        if oWar then
            oWar:WarEnd(mArgs)
        end
        self:RemoveWar(iWarId)
    elseif sEvent == "remote_war_end_exception" then
        local iWarId = mData.war_id
        local mArgs = mData.war_info
        local oWar = self:GetWar(iWarId)
        if oWar then
            oWar:WarEnd(mArgs)
        end
        self:RemoveWar(iWarId)
    end
    return true
end

function CWarMgr:OnLeaveWar(oPlayer,mData,oNowWar)
    local bEscape = mData.escape
    local mWarInfo = mData.war_info
    local bDead = mData.is_dead
    local iAutoPf = mData.auto_pf or 0
    local mSumAutoPf = mData.sum_autopf or {}
    local mUpdateInfo = mData.updateinfo or {}
    local iAutoFight = mData.auto_fight
    local sGamePlay = oNowWar.m_mInfo.GamePlay or ""
    local iWarType = oNowWar.m_iWarType

    if bEscape then
        local iPid = oPlayer:GetPid()
        local oTeam = oPlayer:HasTeam()
        if oTeam and oTeam:IsTeamMember(iPid) and oTeam:MemberSize() >1  then
            oTeam:ShortLeave(iPid)
        end
    end
    if mWarInfo then
        local iAttackCnt = mWarInfo["attack_cnt"] or 0
        local iAttackedCnt = mWarInfo["attacked_cnt"] or 0
        self:OnLeaveWarDelLast(oPlayer, bDead, sGamePlay, iAttackCnt, iAttackedCnt)
    end
    oPlayer.m_oActiveCtrl:SetAutoPerform(iAutoPf)
    oPlayer.m_oActiveCtrl:SetAutoFight(iAutoFight)
    local bRelife = oPlayer:ResumeBaoShi(mData.baoshi or 1,sGamePlay)
    for summid, iPf in pairs(mSumAutoPf) do
        local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
        if oSummon then
            oSummon:SetAutoPerform(iPf)
        end
    end
    for iType , mInfo in pairs(mUpdateInfo) do
        if iType == gamedefines.WAR_WARRIOR_TYPE.SUMMON_TYPE then
            for summid , mSubInfo in pairs(mInfo) do
                local oSummon = oPlayer.m_oSummonCtrl:GetSummon(summid)
                if oSummon then
                    mSubInfo.relife = bRelife
                    mSubInfo.gameplay = sGamePlay
                    mSubInfo.war_type = iWarType
                    oSummon:LeaveWar(mSubInfo)
                end
            end
            if bRelife then
                for _,obj in pairs(oPlayer.m_oSummonCtrl:SummonList()) do
                    if obj:GetMaxHP() ~= obj:GetData("hp") then
                        obj:SetData("hp", obj:GetMaxHP())
                        obj:PropChange("hp")
                    end
                    if obj:GetMaxMP() ~= obj:GetData("mp") then
                        obj:SetData("mp", obj:GetMaxMP())
                        obj:PropChange("mp")
                    end
                end
            end
        elseif iType == gamedefines.WAR_WARRIOR_TYPE.PARTNER_TYPE then
            for partnerid , mSubInfo in pairs(mInfo) do
                local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(partnerid)
                if oPartner then
                    mSubInfo.relife = bRelife
                    mSubInfo.gameplay = sGamePlay
                    oPartner:LeaveWar(mSubInfo)
                end
            end
            if bRelife then
                local  mPartner= oPlayer.m_oPartnerCtrl:GetAllPartner()
                for _,obj in pairs(mPartner) do
                    if obj:GetMaxHp() ~= obj:GetData("hp") then
                        obj:SetData("hp", obj:GetMaxHp())
                        obj:PropChange("hp")
                    end
                    if obj:GetMaxMp() ~= obj:GetData("mp") then
                        obj:SetData("mp", obj:GetMaxMp())
                        obj:PropChange("mp")
                    end
                end
            end
        elseif iType == gamedefines.WAR_WARRIOR_TYPE.PLAYER_TYPE then
            for pid , mSubInfo in pairs(mInfo) do
                local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(pid)
                if oTarget == oPlayer then
                    mSubInfo.relife = bRelife
                    mSubInfo.gameplay = sGamePlay
                    oPlayer:LeaveWar(mSubInfo)
                end
            end
        end
    end
    self:OnLeaveWarClearLock(oPlayer)
end

function CWarMgr:OnLeaveWarDelLast(oPlayer, bDead, sGamePlay, iAttackCnt, iAttackedCnt)
    local iSubLast
    local bNeedFix
    local bHasNeedFix = oPlayer.m_oItemCtrl:HasNeedFixBuff(oPlayer)
    local oWeapon = oPlayer.m_oItemCtrl:GetItem(1)
    local bSubDead, bHasEquip = false, false
    if bDead and not gamedefines.NOT_SUB_DEAD_LAST[sGamePlay] then
        bSubDead = true
    end

    if oWeapon then
        if oWeapon:IsValid() then
            if iAttackCnt > 0 or bSubDead then
                local iCurAttackCnt = math.floor(iAttackCnt + oWeapon:GetWarExAttackCnt())
                iSubLast = 0
                iSubLast = iCurAttackCnt // 10
                if bSubDead then
                    iSubLast = iSubLast + oWeapon:DeadDelLast()
                end
                iCurAttackCnt = iCurAttackCnt % 10
                if iSubLast > 0 and oWeapon:GetLast() > 0 then
                    oWeapon:AddLast(-iSubLast, true)
                end
                oWeapon:SetWarExAttackCnt(iCurAttackCnt)
                bHasEquip = true
            end
            bNeedFix = bNeedFix or oWeapon:IsNeedFix()
        else
            bNeedFix = true
        end
    end
    for i = 2, 6 do
        local oEquip = oPlayer.m_oItemCtrl:GetItem(i)
        if oEquip then
            if oEquip:IsValid() then
                if iAttackedCnt > 0 or bSubDead then
                    local iCurAttackedCnt = math.floor(iAttackedCnt + oEquip:GetWarExAttackedCnt())
                    iSubLast = iCurAttackedCnt // 10
                    iCurAttackedCnt = iCurAttackedCnt % 10
                    if bSubDead then
                        iSubLast = iSubLast + oEquip:DeadDelLast()
                    end
                    if iSubLast > 0 and oEquip:GetLast() > 0 then
                        oEquip:AddLast(-iSubLast, true)
                    end
                    oEquip:SetWarExAttackedCnt(iCurAttackedCnt)
                end
                bNeedFix = bNeedFix or oEquip:IsNeedFix()
                bHasEquip = true
            else
                bNeedFix = true
            end
        end
    end
    if bSubDead and bHasEquip then
        oPlayer:NotifyMessage(global.oItemHandler:GetTextData(1048))
    end
    if bNeedFix then
        oPlayer.m_oItemCtrl:NeedFixEquips(oPlayer, true)
        if oPlayer.m_oItemCtrl:IsEquipsNeedTipsFix(oPlayer, false) then
            oPlayer.m_oItemCtrl:ToTipsFixEquips(oPlayer)
        end
    elseif bHasNeedFix then
        record.warning("equips fixed after war, pid:%d", oPlayer:GetPid())
        oPlayer.m_oItemCtrl:NeedFixEquips(oPlayer, false)
    end
end

function CWarMgr:SetCallback(iWarId,fCallback)
    local oWar = self:GetWar(iWarId)
    if oWar then
        oWar:SetCallback(fCallback)
    end
end

function CWarMgr:SetOtherCallback(iWarId, sKey, fCallback)
    local oWar = self:GetWar(iWarId)
    if oWar then
        oWar:SetOtherCallback(sKey, fCallback)
    end
end

function CWarMgr:WarUseItem(iWarId, iPid, iItemId, iAmount, bSucc)
    local oNotifyMgr = global.oNotifyMgr
    local oWar = self:GetWar(iWarId)
    assert(oWar, string.format("WarUseItem err: no war %d %s", iWarId, iPid))
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    assert(oPlayer, string.format("WarUseItem err: no player %d", iPid))
    local oPlayerWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if not oPlayerWar then
        record.warning(string.format("WarUseItem err: no war %s", iPid)) 
        return 
    end
    -- assert(oPlayerWar, string.format("WarUseItem err: no same war %s", iPid))
    assert(oPlayerWar.m_iWarId == iWarId, string.format("WarUseItem err: error warid %d %d", oWar.m_iWarId, iWarId))

    local oItem = oPlayer.m_oItemCtrl:HasItem(iItemId)
    if not bSucc then
        if self:GetUseItemCnt(iPid, iItemId) > 0 then
            self:SubUseItem(iPid, iItemId)
        end
    else
        assert(oItem, string.format("WarUseItem err: no item %d", iItemId))
        if self:GetUseItemCnt(iPid, iItemId) > 0 and iAmount > 0 then
            self:SubUseItem(iPid, iItemId)
            if oItem:CanSubOnWarUse() then
                oPlayer:RemoveOneItemAmount(oItem,iAmount,"WarUseItem", {cancel_tip=true,cancel_chat=true})
            end
            oItem = oPlayer.m_oItemCtrl:HasItem(iItemId)
        end
    end

    if oItem and self:GetUseItemCnt(iPid, iItemId) <= 0 then
        oItem:ClearWarLock()
    end
end

function CWarMgr:OnWarCapture(mData)
    local iWarId = mData.warid
    local iPid = mData.pid
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oNowWar and oNowWar:GetWarId() == iWarId then
        oNowWar:OtherCallback("OnWarCapture", mData)
    end
end

function CWarMgr:RecordUseItem(iPid, itemid)
    local mItems = self.m_mRecordUseItem[iPid]
    if not mItems then
        mItems = {}
        self.m_mRecordUseItem[iPid] = mItems
    end
    local iCnt = mItems[itemid] or 0
    mItems[itemid] = iCnt + 1
end

function CWarMgr:GetUseItemCnt(iPid, itemid)
    local mItems = self.m_mRecordUseItem[iPid] or {}
    return mItems[itemid] or 0
end

function CWarMgr:SubUseItem(iPid, itemid)
    local mItems = self.m_mRecordUseItem[iPid]
    if not mItems then
        return
    end
    local iCnt = mItems[itemid] or 0
    mItems[itemid] = math.max(0, iCnt - 1)
    self.m_mRecordUseItem[iPid] = mItems
end

function CWarMgr:OnLeaveWarClearLock(oPlayer)
    local iPid = oPlayer:GetPid()
    if not self.m_mRecordUseItem[iPid] then
        return
    end
    for itemid, _ in pairs(self.m_mRecordUseItem[iPid]) do
        local oItem = oPlayer.m_oItemCtrl:HasItem(itemid)
        if oItem then
            oItem:ClearWarLock()
        end
    end
    self.m_mRecordUseItem[iPid] = nil
end


CWar = {}
CWar.__index = CWar
inherit(CWar, logic_base_cls())

function CWar:New(id, iWarType, iSysType, mInfo)
    local o = super(CWar).New(self)
    o.m_iWarId = id
    o.m_iWarType = iWarType
    o.m_iSysType = iSysType
    o.m_mInfo = mInfo
    o.m_iRemoteAddr = nil
    o.m_mPlayers = {}
    o.m_mCamp = {}
    o.m_mObservers = {}
    o.m_mEnterSummon = {}
    o.m_mEnterPartner = {}
    o.m_Callback = nil
    o.m_mOtherCallback = {}
    o.m_EscapeCallback = nil
    o:Init()
    return o
end

function CWar:Init()
    if self.m_iWarType == gamedefines.WAR_TYPE.PVE_TYPE and not self.m_mInfo.auto_start then
        self.m_mInfo.auto_start = 1
    end
end

function CWar:Release()
    interactive.Send(self.m_iRemoteAddr, "war", "RemoveRemote", {war_id = self.m_iWarId})
    self.m_mOtherCallback = {}
    super(CWar).Release(self)
end

function CWar:GetWarId()
    return self.m_iWarId
end

function CWar:GetCamp(pid)
    return self.m_mCamp[pid] or 1
end

function CWar:ConfirmRemote()
    local oWarMgr = global.oWarMgr
    local iRemoteAddr = oWarMgr:SelectRemoteWar()
    self.m_iRemoteAddr = iRemoteAddr
    local mInfo = {
        war_id = self.m_iWarId,
        war_type = self.m_iWarType,
        war_info = self.m_mInfo,
        sys_type=self.m_iSysType,
    }
    interactive.Send(iRemoteAddr, "war", "ConfirmRemote", mInfo)
end

function CWar:VaildLeave(oPlayer)
    return true
end

function CWar:VaildEnter(oPlayer)
    return true
end

function CWar:RemoteLeavePlayer(oPlayer,bEscape)
    local iPid = oPlayer:GetPid()
    oPlayer.m_oActiveCtrl:ClearNowWarInfo()
    oPlayer:SetLogoutJudgeTime()
    if self.m_mPlayers[iPid] then
        self.m_mPlayers[iPid] = nil
        self.m_mCamp[iPid] = nil
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:OnLeaveWar(oPlayer)
        oSceneMgr:ReEnterScene(oPlayer)
    end
    if bEscape then
        self:OtherCallback("OnLeave", oPlayer)

        if self.m_sClassType then
            analylog.LogWarInfo(oPlayer, self.m_sClassType, self.m_iIdx, 4)
        end
    end
    return true
end

function CWar:LeavePlayer(oPlayer)
    local iPid = oPlayer:GetPid()
    oPlayer.m_oActiveCtrl:ClearNowWarInfo()
    oPlayer:SetLogoutJudgeTime()
    if self.m_mPlayers[iPid] then
        self.m_mPlayers[iPid] = nil
        self.m_mCamp[iPid] = nil
        interactive.Send(self.m_iRemoteAddr, "war", "LeavePlayer", {war_id = self.m_iWarId, pid = iPid})
    elseif self.m_mObservers[iPid] then
        self.m_mObservers[iPid] = nil
        interactive.Send(self.m_iRemoteAddr, "war", "LeaveObserver", {war_id = self.m_iWarId, pid = iPid})
        local oTeam = oPlayer:HasTeam()
        if oTeam then
            oTeam:OnLeaveObserver(oPlayer)
        end
    else
        return false
    end
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnLeaveWar(oPlayer)
    oSceneMgr:ReEnterScene(oPlayer)
    return true
end

function CWar:EnterPlayer(oPlayer, mInfo)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnEnterWar(oPlayer)
    self:InitWarSceneInfo(oPlayer)

    oPlayer.m_oActiveCtrl:SetNowWarInfo({
        now_war = self.m_iWarId,
    })
    local mInitInfo = self.m_mInfo or {}
    local mData = oPlayer:PackWarInfo(mInitInfo)
    local sGamePlay = mInitInfo.GamePlay or ""
    if sGamePlay == "arena" then
        mData.hp = mData.max_hp
        mData.mp = mData.max_mp
    end
    mData.is_leader = oPlayer:IsTeamLeader() and 1 or nil
    mData.is_single = oPlayer:IsSingle() and 1 or nil
    if self.PackFunc then
        self:PackFunc(oPlayer, mData, "enterplayer")
    end

    if not mInfo.nosumm then
        local oCurrentSum
        if mInfo.summid then
            oCurrentSum = oPlayer.m_oSummonCtrl:GetSummon(mInfo.summid)
        else
            oCurrentSum = oPlayer.m_oSummonCtrl:GetFightSummon()
        end
        if oCurrentSum then
            local bCanFight, sMsg = oCurrentSum:CanFight(oPlayer)
            if not bCanFight then
                oPlayer:NotifyMessage(sMsg)    
            else
                mData.summon = {
                    sumdata = oCurrentSum:PackWarInfo(oPlayer),
                    sumkeep = oPlayer.m_oSummonCtrl:PacketWarKeepSummon(oCurrentSum),
                }
                local iSumID = oCurrentSum.m_iID
                self.m_mEnterSummon[oPlayer:GetPid()] = iSumID
            end
        end
    end
    self.m_mPlayers[oPlayer:GetPid()] = true
    self.m_mCamp[oPlayer:GetPid()] = mInfo.camp_id
    self:GS2CShowWar(oPlayer)
    oPlayer:SetLogoutJudgeTime(-1)
    interactive.Send(self.m_iRemoteAddr, "war", "EnterPlayer", {war_id = self.m_iWarId, pid = oPlayer:GetPid(), data = mData, camp_id = mInfo.camp_id})
    oPlayer:OnEnterWar(false)
    return true
end

function CWar:ReEnterPlayer(oPlayer)
    if self.m_mObservers[oPlayer:GetPid()] then
        local mArgs = self.m_mObservers[oPlayer:GetPid()]
        self:EnterObserver(oPlayer, mArgs)
        return true
    else
        self:GS2CShowWar(oPlayer)
        oPlayer:SetLogoutJudgeTime(-1)
        interactive.Send(self.m_iRemoteAddr, "war", "ReEnterPlayer", {war_id = self.m_iWarId, pid = oPlayer:GetPid()})
        return true
    end
end

function CWar:GS2CShowWar(oPlayer)
    local iMap, iX, iY = self:GetWarSceneInfo()
    local mNet = {
        war_id = self.m_iWarId,
        war_type = self.m_iWarType,
        sys_type = self.m_iSysType,
        sky_war = self.m_mInfo.sky_war,
        weather = self.m_mInfo.weather,
        is_bosswar = self.m_mInfo.is_bosswar and 1 or 0,
        tollgate_group = self.m_mInfo.tollgate_group,
        tollgate_id = self.m_mInfo.tollgate_id,
        barrage_show = self.m_mInfo.barrage_show or 0,
        barrage_send = self.m_mInfo.barrage_send or 0,
        map_id = iMap,
        x = iX,
        y = iY,
    }
    oPlayer:Send("GS2CShowWar", mNet)
end

function CWar:EnterObserver(oPlayer, mArgs)
    local oSceneMgr = global.oSceneMgr
    oSceneMgr:OnEnterWar(oPlayer)

    oPlayer.m_oActiveCtrl:SetNowWarInfo({
        now_war = self.m_iWarId,
    })

    self.m_mObservers[oPlayer:GetPid()] = mArgs
    self:GS2CShowWar(oPlayer)
    oPlayer:SetLogoutJudgeTime(-1)
    interactive.Send(self.m_iRemoteAddr, "war", "EnterObserver", {war_id = self.m_iWarId, pid = oPlayer:GetPid(), args = mArgs})
    return true
end

function CWar:RemoteLeaveObserver(oPlayer)
    local iPid = oPlayer:GetPid()
    oPlayer.m_oActiveCtrl:ClearNowWarInfo()
    oPlayer:SetLogoutJudgeTime()
    if self.m_mObservers[iPid] then
        self.m_mObservers[iPid] = nil
        local oSceneMgr = global.oSceneMgr
        oSceneMgr:OnLeaveWar(oPlayer)
        oSceneMgr:ReEnterScene(oPlayer)
    end
end

function CWar:ValidEnterPartner()
    return true
end

function CWar:EnterPartner(oPlayer, mData, iSize)
    if iSize < 1 then return end

    if not self:ValidEnterPartner() then
        return
    end

    local lEnter
    if mData.partners then
        lEnter = mData.partners
    else
        lEnter = oPlayer.m_oPartnerCtrl:GetCurrLineupPos()
    end
    if not lEnter or #lEnter <= 0 then return end

    local lData, iCount = {}, 0
    for i = 1, #lEnter do
        local ipn = lEnter[i]
        local oPartner = oPlayer.m_oPartnerCtrl:GetPartner(ipn)
        if oPartner then
            table.insert(lData, oPartner:PackWarInfo(oPlayer, self))
            self.m_mEnterPartner[ipn] = oPlayer:GetPid()
            iCount = iCount + 1
        end
        if iCount >= iSize then
            break
        end
    end

    interactive.Send(self.m_iRemoteAddr, "war", "EnterPartnerList", {
        war_id = self.m_iWarId,
        pid = oPlayer:GetPid(),
        data = lData,
        camp_id = mData.camp_id,
    })
end

function CWar:EnterRoPlayer(oRoInfo, mInfo, bIgnoreSummon)
    self:EnterRoPlayer2(oRoInfo:PackWarInfo(), oRoInfo:PacketSummonWarInfo(), oRoInfo:PacketWarKeepSummon(), mInfo, bIgnoreSummon)
end

function CWar:EnterRoPlayer2(mRoInfo, mRoSumm, mRoKeepSum, mInfo, bIgnoreSummon)
    local mData = mRoInfo
    if not bIgnoreSummon then
        mData.summon = {
            sumdata = mRoSumm,
            sumkeep = mRoKeepSum,
        }
    end
    interactive.Send(self.m_iRemoteAddr, "war", "EnterRoPlayer", {
        war_id = self.m_iWarId,
        camp_id = mInfo.camp_id,
        data = mData,
    })
end

function CWar:EnterRoPartnerList(oRoInfo, mInfo, iLimit)
    local lPartnerInfo = oRoInfo:PackPartnerWarInfo()
    self:EnterRoPartnerList2(lPartnerInfo, mInfo, iLimit)
end

function CWar:EnterRoPartnerList2(lPartnerInfo, mInfo, iLimit)
    local iLen = #lPartnerInfo
    iLimit = math.min(iLimit or iLen, iLen)
    local lResult = {}
    for i = 1, iLimit do
        table.insert(lResult, lPartnerInfo[i])
    end

    interactive.Send(self.m_iRemoteAddr, "war", "EnterRoPartnerList", {
        war_id = self.m_iWarId,
        camp_id = mInfo.camp_id,
        data = lResult,
    })
end

function CWar:PrepareCamp(iCamp, mInfo)
    interactive.Send(self.m_iRemoteAddr, "war", "PrepareCamp", {war_id = self.m_iWarId, info = mInfo, camp=iCamp})
end

function CWar:WarPrepare(mInfo, mConfig)
    interactive.Send(self.m_iRemoteAddr, "war", "WarPrepare", {war_id = self.m_iWarId, info = mInfo, config = mConfig, })
    return true
end

function CWar:WarStart(mInfo)
    interactive.Send(self.m_iRemoteAddr, "war", "WarStart", {war_id = self.m_iWarId, info = mInfo})
    return true
end

function CWar:SendCurrentChat(oPlayer, mData)
    interactive.Send(self.m_iRemoteAddr, "war", "WarChat", {war_id = self.m_iWarId, net = mData})
    return true
end

function CWar:NotifyDisconnected(oPlayer)
    interactive.Send(self.m_iRemoteAddr, "war", "NotifyDisconnected", {war_id = self.m_iWarId, pid = oPlayer:GetPid()})
    return true
end

function CWar:Forward(sCmd, iPid, mData)
    interactive.Send(self.m_iRemoteAddr, "war", "Forward", {pid = iPid, war_id = self.m_iWarId, cmd = sCmd, data = mData})
    return true
end

function CWar:TestCmd(sCmd, iPid, mData)
    interactive.Send(self.m_iRemoteAddr, "war", "TestCmd", {pid = iPid, war_id = self.m_iWarId, cmd = sCmd, data = mData})
    return true
end

function CWar:ForceRemoveWar(iWarResult)
    iWarResult = iWarResult or 2
    interactive.Send(self.m_iRemoteAddr, "war", "ForceRemoveWar", {war_id = self.m_iWarId, war_result = iWarResult})
end

function CWar:SetCallback(fCallback)
    self.m_Callback = fCallback
end

function CWar:SetOtherCallback(sKey, fCallback)
    self.m_mOtherCallback[sKey] = fCallback
end

function CWar:Callback(mInfo)
    if not self.m_Callback then
        return
    end
    self.m_Callback(mInfo)
end

function CWar:OtherCallback(sKey, mInfo)
    local fCallback = self.m_mOtherCallback[sKey]
    if fCallback then
        fCallback(mInfo)
    end
end

function CWar:WarEnd(mArgs)
    local mBakArgs=extend.Table.deep_clone(mArgs)
    mArgs.enterpartner = self.m_mEnterPartner
    mArgs.entersummon = self.m_mEnterSummon
    self:Callback(mArgs)
    self:PreWarEnd(mBakArgs)
    self:OnWarEnd(mBakArgs)
end

function CWar:CalDeadMonster(mInfo)
    if self.m_iWarType ~= gamedefines.WAR_TYPE.PVE_TYPE then
        return 0
    end
    return table_get_depth(mInfo, {"monster_info", "monster_wid_dead", 2}) or 0
end

function CWar:PreWarEnd(mArgs)
    local iTotalDead = self:CalDeadMonster(mArgs)
    local oWorldMgr = global.oWorldMgr
    local mTeam={}
    local mPlayer = extend.Table.deep_clone(mArgs.player)
    for side,mDie in ipairs(mArgs.die) do
        if not mPlayer[side] then
            mPlayer[side] = {}
        end
        for _,pid in ipairs(mDie) do
            table.insert(mPlayer[side],pid)
        end
    end

    for side,lPlayer in pairs(mPlayer) do
        for _,pid in ipairs(lPlayer) do
            local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
            if oPlayer then
                oPlayer:WarEnd()
                if mArgs.win_side == gamedefines.WAR_WARRIOR_SIDE.FRIEND and iTotalDead > 0 then
                    global.oRankMgr:PushDataToEveryDayRank(oPlayer, "kill_monster", {cnt=iTotalDead})
                end
            end
            if oPlayer and oPlayer:HasTeam() then
                local oTeam = oPlayer:HasTeam()
                if oTeam:IsLeader(pid) then
                    table.insert(mTeam,oTeam)
                end
            end
        end
    end

    for _ , oTeam in ipairs(mTeam) do
        oTeam:WarEnd()
    end
end

function CWar:OnWarEnd(mArgs)
    if mArgs.war_exception then
        return
    end
    local oFriendMgr = global.oFriendMgr
    local lAllPids = mArgs.player[mArgs.win_side] or {}
    local lPids = {}
    for _, iPid in pairs(lAllPids) do
        for _, iTarget in pairs(lPids) do
            oFriendMgr:AddFriendDegree(iPid, iTarget, 1, true)
        end
        table.insert(lPids, iPid)
    end
    local oJbObj = global.oHuodongMgr:GetHuodong("jiebai")
    if oJbObj then
        oJbObj:OnWarEnd(mArgs)
    end
    self:TriggerPromote(mArgs)
end

function CWar:TriggerPromote(mArgs)
    if not self.m_mInfo then
        return
    end
    if not self.m_mInfo.GamePlay then
        return
    end
    local sGamePlay = self.m_mInfo.GamePlay
    if extend.Array.find({"jjc","challenge"},sGamePlay) then
        return
    end
    local mRes = res["daobiao"]["promote"]["warfail"]
    if not mRes[self.m_mInfo.GamePlay] then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local winside = mArgs.win_side
    local failside
    if winside==1 then
        failside = 2
    else
        failside = 1
    end
    local mNet = {
        war_id = self.m_iWarId,
        gameplay = self.m_mInfo.GamePlay,
    }
    for _,pid in ipairs(mArgs.player[failside]) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CWarFail", mNet)
            oPlayer.m_mPromoteCtrl:TriggerPromote(oPlayer,1)
        end
    end
    for _,pid in ipairs(mArgs.die[failside]) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            oPlayer:Send("GS2CWarFail", mNet)
            oPlayer.m_mPromoteCtrl:TriggerPromote(oPlayer,1)
        end
    end
end

function CWar:GetTeamLeaderGrade()
    local oWorldMgr = global.oWorldMgr
    for pid,_ in pairs(self.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                return oTeam:GetLeaderGrade()
            else
                return oPlayer:GetGrade()
            end
        end
    end
end

function CWar:GetTeamAveGrade()
    local oWorldMgr = global.oWorldMgr
    for pid,_ in pairs(self.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                return oTeam:GetTeamAveGrade()
            else
                return oPlayer:GetGrade()
            end
        end
    end
end

function CWar:GetTeamMaxGrade()
    local oWorldMgr = global.oWorldMgr
    for pid,_ in pairs(self.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                return oTeam:GetTeamMaxGrade()
            else
                return oPlayer:GetGrade()
            end
        end
    end
end

function CWar:GetTeamMinGrade()
    local oWorldMgr = global.oWorldMgr
    for pid,_ in pairs(self.m_mPlayers) do
        local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            local oTeam = oPlayer:HasTeam()
            if oTeam then
                return oTeam:GetTeamMinGrade()
            else
                return oPlayer:GetGrade()
            end
        end
    end
end

function CWar:GetRemoteAddr()
    return self.m_iRemoteAddr
end

function CWar:WarBulletBarrage(oPlayer, mData)
    local iSend = self.m_mInfo.barrage_send
    if not iSend or iSend <= 0 then
        return
    end
    interactive.Send(self.m_iRemoteAddr, "war", "WarBulletBarrage", {war_id = self.m_iWarId, pid = oPlayer:GetPid(), args = mData})
end

function CWar:InWar(iPid)
    return self.m_mPlayers[iPid]
end

function CWar:InObserver(iPid)
    return self.m_mObservers[iPid]
end

function CWar:InitWarSceneInfo(oPlayer)
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if not oScene then return end

    local mNowPos = oPlayer.m_oActiveCtrl:GetNowPos() 
    self.m_mScene = {
        map_id = oScene:MapId(),
        x = mNowPos.x or 0,
        y = mNowPos.y or 0,
    }
end

function CWar:GetWarSceneInfo()
    if not self.m_mScene then return end
    
    return self.m_mScene.map_id, geometry.Cover(self.m_mScene.x), geometry.Cover(self.m_mScene.y)
end

function CWar:ForceWarEnd()
    interactive.Send(self.m_iRemoteAddr, "war", "ForceWarEnd", {war_id = self.m_iWarId})
end
