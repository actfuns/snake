local global = require "global"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))


function NewConfirmMgr(...)
    return CConfirmMgr:New(...)
end

function ConfirmExpire(iConfirm)
    local oConfirm = global.oConfirmMgr:GetConfirmObj(iConfirm)
    if not oConfirm then return end
    
    oConfirm:DoConfirmExpire()
end

CConfirmMgr = {}
CConfirmMgr.__index = CConfirmMgr
inherit(CConfirmMgr, logic_base_cls())

function CConfirmMgr:New()
    local o = super(CConfirmMgr).New(self)
    o:Init()
    return o
end


function CConfirmMgr:Init()
    self.m_iDispatchId = 0
    self.m_mConfirmObj = {}
    self.m_mTeamConfirm = {}
end

function CConfirmMgr:Release()
    for _, oConfirm in pairs(self.m_mConfirmObj) do
        baseobj_delay_release(oConfirm)
    end
    self.m_mConfirmObj = {}
    self.m_mTeamConfirm = {}
    super(CConfirmMgr).Release(self)
end

function CConfirmMgr:DispatchID()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CConfirmMgr:DoConfirm(oPlayer, iConfirm, iAnswer)
    local oConfirm = self:GetConfirmObj(iConfirm)
    if not oConfirm then return end
    
    if iAnswer == 1 then
        oConfirm:DoConfirm(oPlayer)
    else
        oConfirm:DoCancle(oPlayer)        
    end
end

-- function CConfirmMgr:TeamFightCallBack(obj, mArgs)
--     if not obj and not is_release(obj) then return end

--     obj:TrueFight(table.unpack(mArgs))
-- end

function CConfirmMgr:CreateTeamFightConfirm(oPlayer, sName, fCallBack)
    local oTeam = oPlayer:HasTeam()
    if not oTeam or oTeam:GetConfirmObj() then return end

    local lConfirmPid = oTeam:GetWarConfirmPid()
    if #lConfirmPid <= 0 then
        fCallBack()
        return
    end

    local iConfirm = self:DispatchID()
    local oConfirm = CConfirmObj:New(iConfirm, oPlayer:GetPid(), lConfirmPid, fCallBack, 30)
    oConfirm:SetTeam(oTeam:TeamID())
    self:AddConfirm(oConfirm)
    self:SetTeamConfirm(oTeam:TeamID(), iConfirm)
    oPlayer:NotifyMessage("等待队员响应战斗")

    local mData = {}
    mData["sContent"] = string.format("队长正在挑战【%s】，是否同意进入战斗？", sName) 
    mData["sConfirm"] = "同意"
    mData["sCancle"] = "拒绝"
    mData["time"] = 30
    mData["close_btn"] = 1

    local fConfirm = function (oPlayer, mData)
        self:DoConfirm(oPlayer, iConfirm, mData["answer"])
    end
    local oCbMgr = global.oCbMgr
    for _, iPid in pairs(lConfirmPid) do
        local iSession = oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil, fConfirm)
        oConfirm:SetSession(iPid, iSession)
    end
end

function CConfirmMgr:GetConfirmObj(iConfirm)
    return self.m_mConfirmObj[iConfirm]
end

function CConfirmMgr:AddConfirm(oConfirm)
    self.m_mConfirmObj[oConfirm:ConfirmID()] = oConfirm
    oConfirm:Schedule()
end

function CConfirmMgr:SetTeamConfirm(iTeam, iConfirm)
    self.m_mTeamConfirm[iTeam] = iConfirm
end

function CConfirmMgr:GetConfrimObjByTeamId(iTeam)
    local iConfirm = self.m_mTeamConfirm[iTeam]
    return self:GetConfirmObj(iConfirm)
end

function CConfirmMgr:DelConfirm(iConfirm)
    local oConfirm = self.m_mConfirmObj[iConfirm]
    if not oConfirm then return end

    self:SetTeamConfirm(oConfirm:GetTeamID(), nil)
    baseobj_delay_release(oConfirm)
    self.m_mConfirmObj[iConfirm] = nil
end


CConfirmObj = {}
CConfirmObj.__index = CConfirmObj
inherit(CConfirmObj, logic_base_cls())

function CConfirmObj:New(iConfirm, iPid, lConfirmPid, fCallBack, iTime)
    local o = super(CConfirmObj).New(self)
    o.m_iConfirm = iConfirm
    o.m_iPid = iPid
    o.m_lConfirmPid = lConfirmPid
    o.m_mSession = {}
    o.m_fCallBack = fCallBack
    o.m_iConfirmTime = iTime or 30
    o.m_iTeam = 0
    return o
end

function CConfirmObj:Init()
end

function CConfirmObj:Release()
    self.m_fCallBack = nil
    self.m_lConfirmPid = {}
    super(CConfirmObj).Release(self)
end

function CConfirmObj:Schedule()
    self:DelTimeCb("_ConfirmExpire")

    local iConfirm = self:ConfirmID()
    local f = function ()
        ConfirmExpire(iConfirm)
    end
    self:AddTimeCb("_ConfirmExpire", self.m_iConfirmTime * 1000, f)
end

function CConfirmObj:ConfirmID()
    return self.m_iConfirm
end

function CConfirmObj:GetTeamID()
    return self.m_iTeam
end

function CConfirmObj:SetTeam(iTeam)
    self.m_iTeam = iTeam
end

function CConfirmObj:SetSession(iPid, iSession)
    self.m_mSession[iPid] = iSession
end

function CConfirmObj:DoConfirmExpire()
    self:DelTimeCb("_ConfirmExpire")

    global.oConfirmMgr:DelConfirm(self:ConfirmID())
end

function CConfirmObj:DoConfirm(oPlayer)
    if not table_in_list(self.m_lConfirmPid, oPlayer:GetPid()) then return end

    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local sMsg = string.format("#G%s#n同意进入战斗", oPlayer:GetName())
    global.oChatMgr:SendMsg2Team(sMsg, oTeam:TeamID())
    oTeam:TeamNotify(sMsg)

    for i, iPid in pairs(self.m_lConfirmPid) do
        if iPid == oPlayer:GetPid() then
            table.remove(self.m_lConfirmPid, i)
            break   
        end
    end
    oTeam:SetPlayerConfirm(oPlayer:GetPid())
    if #self.m_lConfirmPid <= 0 then
        oTeam:SetWarConfirm(true)
        if not oTeam:InWar() then
            self.m_fCallBack()
        end
        global.oConfirmMgr:DelConfirm(self:ConfirmID())        
    end
end

function CConfirmObj:DoCancle(oPlayer)
    if not table_in_list(self.m_lConfirmPid, oPlayer:GetPid()) then return end

    local oTeam = oPlayer:HasTeam()
    local sMsg = string.format("#G%s#n拒绝进入战斗", oPlayer:GetName())
    global.oChatMgr:SendMsg2Team(sMsg, oTeam:TeamID())
    global.oConfirmMgr:DelConfirm(self:ConfirmID())
    oTeam:TeamNotify(sMsg)

    local oWorldMgr = global.oWorldMgr
    local lConfirmPid = oTeam:GetWarConfirmPid()
    for _, iPid in pairs(lConfirmPid) do
        if iPid ~= oPlayer:GetPid() then
            local oMem = oWorldMgr:GetOnlinePlayerByPid(iPid)
            local iSession = self.m_mSession[iPid]
            oMem:Send("GS2CRemoveConfirmUI", {msg="战斗取消", session=iSession})
        end
    end
end

function CConfirmObj:OnMemberChange(oTeam)
    local oWorldMgr = global.oWorldMgr
    local lConfirmPid = oTeam:GetWarConfirmPid()
    for _, iPid in pairs(lConfirmPid) do
        local oMem = oWorldMgr:GetOnlinePlayerByPid(iPid)
        if oMem then
            local iSession = self.m_mSession[iPid]
            oMem:Send("GS2CRemoveConfirmUI", {msg="战斗取消", session=iSession})
        end
    end
    global.oChatMgr:SendMsg2Team("战斗取消", oTeam:TeamID())
    global.oConfirmMgr:DelConfirm(self:ConfirmID())    
end




