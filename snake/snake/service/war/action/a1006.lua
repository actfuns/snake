--import module

local global = require "global"

local action = import(service_path("action/actionbase"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewWarAction(...)
    local o = CWarAction:New(...)
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, action.CWarAction)


function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    if not oWar then return end

    local func = function(oCamp, iExclude)
        return GetAliveCount(oCamp, iExcluce)
    end

    local oCamp1 = oWar:GetCampObj(1)
    oCamp1:AddFunction("GetAliveCount", 1006, func)
    local oCamp2 = oWar:GetCampObj(2)
    oCamp2:AddFunction("GetAliveCount", 1006, func)

    local mWarriorMap = oWar:GetWarriorMap()
    for iWid, iCamp in pairs(mWarriorMap) do
        local oWarrior = oWar:GetWarrior(iWid)
        if oWarrior then
            self:DoActionConfig(oWarrior)
        end
    end
end

function CWarAction:DoActionConfig(oWarrior)
    local iType = oWarrior:GetData("type")
    if iType == 11014 or iType == 11015 then
        local func = function(oAttack, mCmd)
            return OnChangeCmd(oAttack, mCmd)
        end
        oWarrior:AddFunction("ChangeCmd", 1003, func)

        oWarrior.m_oBuffMgr:AddBuff(173, 99, {bForce=true})
    end
end

function GetAliveCount(oCamp, iExclude)
    local iTotal = 0
    for iWid, oWarrior in pairs(oCamp.m_mWarriors) do
        if oWarrior:IsDead() then
            goto continue
        end
        if oWarrior:GetPos() == iExclude then
            goto continue
        end
        local iType = oWarrior:GetData('type')
        if iType == 11014 or iType == 11015 then
            goto continue
        end
        iTotal = iTotal + 1
        ::continue::
    end
    return iTotal
end

function OnChangeCmd(oAttack, mCmd)
    if oAttack:IsDead() then return end

    local oWar = oAttack:GetWar()
    if not oWar then return end

    return {cmd="defense", data={action_wid=oAttack:GetWid()}}
end


