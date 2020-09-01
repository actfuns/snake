local global = require "global"
local interactive = require "base.interactive"
local warobj = import(service_path("warobj"))


function NewWar(...)
    local o = CWar:New(...)
    return o
end

CWar = {}
CWar.__index = CWar
inherit(CWar, warobj.CWar)

function CWar:WarEnd()
    self:DelTimeCb("BoutStart")
    self:DelTimeCb("BoutProcess")
    self.m_bWarEnd = true

    local mArgs, mPlayer = {}, {{}, {}, {}}

    if self.m_bBoutOut or self.m_bForce then
        local mSideInfo = {
            [1] = {alive_amount = 0, sum_hp = 0,},
            [2] = {alive_amount = 0, sum_hp = 0,},
        }

        local lSideList = {1, 2}

        for _, iSide in ipairs({1, 2}) do
            local lWarrior = self:GetWarriorList(iSide)
            for _, oWarrior in pairs(lWarrior) do
                if oWarrior:IsAlive() then
                    mSideInfo[iSide].alive_amount = mSideInfo[iSide].alive_amount + 1
                    mSideInfo[iSide].sum_hp = mSideInfo[iSide].sum_hp + oWarrior:GetHp()
                end
            end
        end
        table.sort(lSideList, function(x, y)
            local mSidex = mSideInfo[x]
            local mSidey = mSideInfo[y]
            if mSidex.alive_amount == mSidey.alive_amount then
                if mSidex.sum_hp == mSidey.sum_hp then
                    return x < y
                else
                    return mSidex.sum_hp > mSidey.sum_hp
                end
            else
                return mSidex.alive_amount > mSidey.alive_amount
            end
        end)
        local iWin, iLose = table.unpack(lSideList)

        mArgs.win_side = iWin
        mArgs.bout_out = true
    else
        mArgs.win_side = self.m_iWarResult
        mArgs.bout_out = false
    end

    local l = table_key_list(self.m_mPlayers)
    for _, iPid in ipairs(l) do
        local obj = self:GetPlayerWarrior(iPid)
        if obj then
            table.insert(mPlayer[obj:GetCampId()], iPid)
        end
        self:LeavePlayer(iPid)
    end
    local l = table_key_list(self.m_mObservers)
    for _, iPid in ipairs(l) do
        self:LeaveObserver(iPid)
    end

    mArgs.player = mPlayer
    mArgs.escape = self.m_mEscape
    mArgs.force = self.m_bForce
    mArgs.die = {}

    interactive.Send(".world", "war", "RemoteEvent", {event = "remote_war_end", data = {
        war_id = self:GetWarId(),
        war_info = mArgs,
    }})
end

function CWar:ForceWarEnd()
    if self:IsWarEnd() then return end

    self.m_bForce = true
    self:WarEnd()
end

