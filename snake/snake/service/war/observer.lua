
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))

function NewObserver(...)
    return CObserver:New(...)
end


CObserver = {}
CObserver.__index = CObserver
inherit(CObserver, logic_base_cls())

function CObserver:New(iPid)
    local o = super(CObserver).New(self)
    o.m_iPid = iPid
    return o
end

function CObserver:Init(mInit)
    self.m_iWarId = mInit.war_id
    self.m_iCamp = mInit.camp_id or 1
end

function CObserver:GetPid()
    return self.m_iPid
end

function CObserver:GetCampId()
    return self.m_iCamp
end

function CObserver:IsObserver()
    return true
end

function CObserver:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self:GetWarId())
end

function CObserver:GetWarId()
    return self.m_iWarId
end

function CObserver:Send(sMessage, mData)
    playersend.Send(self.m_iPid, sMessage, mData)
end

function CObserver:Disconnected()
end

function CObserver:SendRaw(sData)
    playersend.SendRaw(self.m_iPid, sData)
end

function CObserver:Notify(sMsg)
    playersend.Send(self.m_iPid,"GS2CNotify",{
        cmd = sMsg
    })
end

function CObserver:Enter()
    local oWar = self:GetWar()
    assert(oWar, "war obj not exist, can't observer")

    self:Send("GS2CStartObserver", {pid=self.m_iPid, war_id=self.m_iWarId, camp_id=self.m_iCamp})

    oWar:GS2CAddAllWarriors(self)

    oWar:SendAll("GS2CWarCampFmtInfo", {
        war_id = oWar:GetWarId(),
        fmt_id1 = oWar.m_lCamps[1]:GetFmtId(),
        fmt_grade1 = oWar.m_lCamps[1]:GetFmtGrade(),
        fmt_id2 = oWar.m_lCamps[2]:GetFmtId(),
        fmt_grade2 = oWar.m_lCamps[2]:GetFmtGrade(),
    })

    local iStatus, iStatusTime = oWar.m_oBoutStatus:Get()
    if iStatus == gamedefines.WAR_BOUT_STATUS.OPERATE then
        self:Send("GS2CWarBoutStart", {
            war_id = oWar:GetWarId(),
            bout_id = oWar.m_iBout,
            left_time = math.max(0, math.floor((iStatusTime + oWar:GetOperateTime() - get_msecond())/1000)),
        })
    elseif iStatus == gamedefines.WAR_BOUT_STATUS.ANIMATION then
        self:Send("GS2CWarBoutEnd", {
            war_id = oWar:GetWarId(),
        })
    end
end
