local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local buffbase = import(service_path("buff/buffbase"))

function ChangeCmd(oAction)
    if not oAction then
        return
    end
    local iWid
    local lWarriors = {}
    local War = oAction:GetWar()
    for k, _ in pairs(War.m_mWarriors) do
        if k ~= oAction:GetWid() then
            local o = War:GetWarrior(k)
            if o and o:IsAlive() and o:IsVisible(oAction, true) then
                table.insert(lWarriors, o)
            end
        end
    end
    if next(lWarriors) then
        iWid = extend.Random.random_choice(lWarriors):GetWid()
    end
    if iWid then
        local cmd = {}
        cmd.cmd = "normal_attack"
        cmd.data = {}
        cmd.data.select_wid = iWid
        return cmd
    end
    return
end

function NewBuff(...)
    local o = CBuff:New(...)
    return o
end

CBuff = {}
CBuff.__index = CBuff
inherit(CBuff, buffbase.CBuff)

function CBuff:CalInit(oWarrior,oBuffMgr)
    local iBout = nil
    local cmd
    local func
    func = function (oAction)
        local War = oAction:GetWar()
        if iBout == War.m_iBout then
            return cmd
        end
        cmd = ChangeCmd(oAction)
        iBout = War.m_iBout
        return cmd
    end
    oWarrior:AddFunction("ChangeCmd", self.m_ID, func)
end

function CBuff:OnRemove(oAction,oBuffMgr)
    oAction:RemoveFunction("ChangeCmd", self.m_ID)
end
