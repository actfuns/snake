local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--节能施法

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, iMP, oPerform)
        return CheckResumeMp(iPerform, oAttack, iMP, oPerform)
    end
    oPerformMgr:AddFunction("CheckResumeMp", self.m_ID, func)
end

function CheckResumeMp(iPerform, oAttack, iMP, oUsePerform)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    if not oUsePerform then return 0 end

    if oUsePerform:ActionType() == gamedefines.WAR_ACTION_TYPE.CURE then
        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oAttack)
        local mExtArg = formula_string(sExtArg, mEnv)
        
        if math.random(100) <= mExtArg.ratio then
            return -math.floor(iMP * mExtArg.mp_sub_ratio / 100)
        end
    end
    return 0
end

