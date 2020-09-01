local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local datactrl = import(lualib_path("public.datactrl"))
local taskdefines = import(service_path("task/taskdefines"))
local gamedefines = import(lualib_path("public.gamedefines")) 

function NewSysOpenMgr(...)
    return CSysOpenMgr:New(...)
end

CSysOpenMgr = {}
CSysOpenMgr.__index = CSysOpenMgr
inherit(CSysOpenMgr, logic_base_cls())

function CSysOpenMgr:OnLogin(oPlayer, bReEnter)
    if not bReEnter then
        oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.UNLOCK_TAG, function(iEvType, mData)
            global.oSysOpenMgr:OnEventUnlockTag(iEvType, mData)
        end)
        oPlayer.m_oTaskCtrl:AddEvent(self, taskdefines.EVENT.LOCK_TAG, function(iEvType, mData)
            global.oSysOpenMgr:OnEventLockTag(iEvType, mData)
        end)
    end

    local mOpenData = res["daobiao"]["open"]
    local lOpenSysList = {}
    local oToolMgr = global.oToolMgr
    for sSysId, mInfo in pairs(mOpenData) do
        if oToolMgr:IsSysOpen(sSysId, oPlayer, true) then
            table.insert(lOpenSysList, sSysId)
        end
    end
    -- oPlayer:SetTemp("opensys", lOpenSysList)
    oPlayer:Send("GS2CLoginOpenSys", {open_sys = lOpenSysList})
end

function CSysOpenMgr:OnEventLockTag(iEvType, mData)
    local iPid = mData.pid
    local iTag = mData.tag
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local lSysIds = table_get_depth(res, {"daobiao", "open_condi", "task_lock", iTag})
    if not lSysIds then
        return
    end
    local oToolMgr = global.oToolMgr
    local mOpenSys = {}
    for _, sSysId in ipairs(lSysIds) do
        if not oToolMgr:IsSysOpen(sSysId, oPlayer, true) then
            mOpenSys[sSysId] = false
        end
    end
    if next(mOpenSys) then
        self:SyncOpenChange(oPlayer, mOpenSys)
    end
end

function CSysOpenMgr:OnEventUnlockTag(iEvType, mData)
    local iPid = mData.pid
    local iTag = mData.tag
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        return
    end
    local lSysIds = table_get_depth(res, {"daobiao", "open_condi", "task_lock", iTag})
    if not lSysIds then
        return
    end
    local oToolMgr = global.oToolMgr
    local mOpenSys = {}
    for _, sSysId in ipairs(lSysIds) do
        if oToolMgr:IsSysOpen(sSysId, oPlayer, true) then
            mOpenSys[sSysId] = true
        end
    end
    if next(mOpenSys) then
        self:SyncOpenChange(oPlayer, mOpenSys)
    end
end

function CSysOpenMgr:OnUpgradeEnd(oPlayer, iFromGrade, iToGrade)
    local mOpenCondiGradeInfo = table_get_depth(res, {"daobiao", "open_condi", "p_grade"})
    local mOpenSys = {}
    local oToolMgr = global.oToolMgr
    for iGrade, lSysIds in pairs(mOpenCondiGradeInfo) do
        if iFromGrade < iGrade and iGrade <= iToGrade then
            for _, sSysId in ipairs(lSysIds) do
                if oToolMgr:IsSysOpen(sSysId, oPlayer, true) then
                    mOpenSys[sSysId] = true
                end
            end
        end
    end
    if next(mOpenSys) then
        self:SyncOpenChange(oPlayer, mOpenSys)
    end
end

function CSysOpenMgr:SyncOpenChange(oPlayer, mOpenSys)
    local lNetOpen = {}
    for sSysId, bOpen in pairs(mOpenSys) do
        table.insert(lNetOpen, {sys = sSysId, open = bOpen and 1 or 0})
    end
    oPlayer:Send("GS2COpenSysChange", {changes = lNetOpen})
end

function CSysOpenMgr:RecheckAllSys(oPlayer)
    local mOpenData = res["daobiao"]["open"]
    local mOpenSys = {}
    local oToolMgr = global.oToolMgr
    for sSysId, mInfo in pairs(mOpenData) do
        mOpenSys[sSysId] = oToolMgr:IsSysOpen(sSysId, oPlayer, true)
    end
    self:SyncOpenChange(oPlayer, mOpenSys)
end

function CSysOpenMgr:BroadCastOpenSys(lSysOpen)
    local mOnline = global.oWorldMgr:GetOnlinePlayerList()
    local lPlayerIds = table_key_list(mOnline)

    local func = function (iPid)
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
        if not oPlayer then return end

        local lNetOpen = {}
        for _,sSys in pairs(lSysOpen) do
            local iOpen = global.oToolMgr:IsSysOpen(sSys, oPlayer, true) and 1 or 0
            global.oSysOpenMgr:OnOpenSys(sSys, oPlayer)
            table.insert(lNetOpen, {
                sys = sSys,
                open = iOpen
            })
        end
        oPlayer:Send("GS2COpenSysChange", {changes = lNetOpen})
    end
    global.oToolMgr:ExecuteList(lPlayerIds, 200, 500, 0, "BroadCastSysOpen", func)
end

function CSysOpenMgr:OnOpenSys(sSys, oPlayer)
    if sSys == "BADGE" then
        oPlayer.m_oTouxianCtrl:PreLogin(oPlayer)
    end
end

function CSysOpenMgr:BroadCastCloseSys(lSysOpen)
    local lNetOpen = {}
    for _,sSys in pairs(lSysOpen) do
        table.insert(lNetOpen, {
            sys = sSys,
            open = 0
        })
    end
    interactive.Send(".broadcast", "channel", "SendChannel", {
        message = "GS2COpenSysChange",
        id = 1,
        type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
        data = {changes = lNetOpen},
        exclude = {},
    })
end
