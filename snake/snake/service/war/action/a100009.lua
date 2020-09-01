local global = require "global"
local extend = require "base.extend"

local firstboutskillaction = import(service_path("action/firstboutskill"))
local gamedefines = import(lualib_path("public.gamedefines"))
local wardefines = import(service_path("fight/wardefines"))

local ACTION_ID = 100009
local ESCAPE_BOUT = 10

function NewWarAction(...)
    local o = CWarAction:New(...)
    o.m_iActionID = 100009
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, firstboutskillaction.CWarAction)

function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    local mSpeekData = mInfo.speek or {}
    mInfo.speek_enable = false

    local iCamp = 2
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local iType = oWarrior:GetData("type")
        if iType == 10001 then --年兽
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10001(oAction)
            end)
            oWarrior:AddFunction("OnBoutStart",ACTION_ID,function (oAction)
                OnBoutStart10001(oAction)
            end)
        end
    end
end

function OnBoutEnd10001(oAction)
    if oAction:IsDead() then
        return 
    end
    local oWar = oAction:GetWar()
    if not oWar then
        return 
    end
    local iBout = oWar:CurBout()
    if iBout == ESCAPE_BOUT then
        oAction:SetExtData("escape_ratio",100)
        global.oActionMgr:WarEscape(oAction)
        oWar.m_iWarResult = 2
        oWar:WarEnd()
    end
end

function OnBoutStart10001(oAction)
    if oAction:IsDead() then
        return 
    end
    local oWar = oAction:GetWar()
    if not oWar then
        return 
    end
    local iBout = oWar:CurBout()
    if iBout <=ESCAPE_BOUT then
        DoSpeek(oAction,"你们最怕啥？我最怕鞭炮",1)
    end
end


function DoSpeek(oWarrior, sContent,iFlag)
    if oWarrior:IsDead() then
        return
    end
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        wid = oWarrior:GetWid(),
        content = sContent,
        flag = iFlag,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end