--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iType = self:Type()   
    local func = function (o)
        OnNewBout(o, iType)
    end
    oAction:AddFunction("OnNewBout", self.m_ID, func)
end

function OnNewBout(oAction, iPerform)
    if oAction:IsDead() then return end

    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local iMp = oPerform:CalSkillFormula({grade=oAction:GetGrade()})
    oAction:GS2CTriggerPassiveSkill(5135)
    global.oActionMgr:DoAddMp(oAction, iMp)
end

