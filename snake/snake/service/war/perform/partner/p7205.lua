--import module

local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"
local pfobj = import(service_path("perform/pfobj"))
local gamedefines = import(lualib_path("public.gamedefines"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--灼烧

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAttack, oVictim, oPerform, iDamage, mArgs)
        OnAttack(iPerform, oAttack, oVictim, oPerform, iDamage, mArgs)
    end
    oPerformMgr:AddFunction("OnAttack", self.m_ID, func)
end

function OnAttack(iPerform, oAttack, oVictim, oUsePerform, iDamage, mArgs)
    local oPerform = oAttack:GetPerform(iPerform)
    if not oPerform then return end

    local sExtArg = oPerform:ExtArg()
    local mEnv = oPerform:SkillFormulaEnv(oAttack, oVictim)
    local mExtArg = formula_string(sExtArg, mEnv)

    if math.random(100) <= mExtArg.ratio then
        local lFriend = oAttack:GetFriendList()
        if not next(lFriend) then return end
       
        local iRemoveCnt = 1 
        lFriend = extend.Random.random_size(lFriend, #lFriend)
        for _, oWarrior in pairs(lFriend) do
            local iRet = oWarrior.m_oBuffMgr:RemoveClassBuff(gamedefines.BUFF_TYPE.CLASS_ABNORMAL, "封印", iRemoveCnt)
            if iRet < iRemoveCnt then break end
        end
    end
end


