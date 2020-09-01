--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))
local buffload = import(service_path("buff.buffload"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--信仰

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oVictim, oAttack, iBuff)
        return CheckAddBuffBout(iPerform, oVictim, oAttack, iBuff)
    end
    oPerformMgr:AddFunction("CheckAddBuffBout", iPerform, func)
end

function CheckAddBuffBout(iPerform, oVictim, oAttack, iBuff)
    if not oVictim or oVictim:IsDead() then
        return 0
    end
    if not oAttack or oAttack:IsDead() then
        return 0
    end

    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return 0 end

    local oBuff = buffload.GetBuff(iBuff)
    if oBuff:BuffType() ~= "封印" then
        return 0
    end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)
    
    if math.random(100) <= mExtArg.buff_bout_add_ratio then
        return mExtArg.buff_bout_add or 0
    else
        return 0
    end
end
