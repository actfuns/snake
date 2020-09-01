local global = require "global"
local skynet = require "skynet"
local pfobj = import(service_path("perform/fabao/fabaobase"))

function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    super(CPerform).TruePerform(self,oAttack, oVictim, iRatio)
    local iRatio = self:CalSkillFormula(oAttack,oVictim,100,{},true)
    local iHpRatio, iMpRatio = iRatio, iRatio
    local oPerform4607 = oAttack:GetPerform(4607)
    if oPerform4607 then
        iHpRatio = iHpRatio + oPerform4607:CalSkillFormula(oAttack, oVictim, 100, {})
    end
    local oPerform4608 = oAttack:GetPerform(4608)
    if oPerform4608 then
        iMpRatio = iMpRatio + oPerform4608:CalSkillFormula(oAttack, oVictim, 100, {})
    end

    local iHp = math.floor(oVictim:GetMaxHp() * iHpRatio / 100)
    local iMp = math.floor(oVictim:GetMaxMp() * iMpRatio / 100)
    global.oActionMgr:DoCureAction(oAttack, oVictim, self, iHp)
    global.oActionMgr:DoAddMp(oVictim, iMp)
    for _,iPerform in pairs({4609,4610}) do
        local oPerform  = oAttack:GetPerform(iPerform)
        if oPerform then
            oPerform:TriggerFaBaoEffect(oVictim)
        end
    end
end
