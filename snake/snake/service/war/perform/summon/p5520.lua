--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/summon/pfbase"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

function OnBuffRemove(iPerform, oBuff, oAction, oBuffMgr)
    if not oBuff or not oAction or not oBuffMgr then return end
    local oPerform = oAction:GetPerform(iPerform)
    if not oPerform then return end

    local iRatio = oPerform:CalSkillFormula()
    if math.random(100) > iRatio then return end
    
    if oBuff:BuffId() ~= 130 then return end

    local iBout = 2
    local oTargetPf = oAction:GetPerform(5132)
    if oTargetPf then 
        iBout = oTargetPf:GetBoutNum()
    end

    iBout = iBout + 1
    oBuffMgr:AddBuff(130, iBout, {})
    local oNewBuff = oBuffMgr:HasBuff(130)
    if oNewBuff then
        oNewBuff:SubBout()
    end
end


-- 隐遁(天赋)
CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:New(pfid)
    local o = super(CPerform).New(self, pfid)
    return o
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function (oBuff, oAct, oBuffMgr)
        return OnBuffRemove(iPerform, oBuff, oAct, oBuffMgr)        
    end
    oAction:AddFunction("OnBuffRemove", self.m_ID, func)
end

