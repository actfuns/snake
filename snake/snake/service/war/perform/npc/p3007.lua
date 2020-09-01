
--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--真·轮回

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    if oAttack:IsNpcLike() and oAttack:GetCampId() == 2 then
        local oWar = oAttack:GetWar()
        oWar:SendAll("GS2CWarriorSeqSpeek", {
            war_id = oAttack:GetWarId(),
            speeks = {
                {
                    wid = oAttack:GetWid(),
                    content = "老衲在此，岂容尔等放肆！",
                },
            },
            block_ms = 0,
            block_action = 0,
        })
    end
    super(CPerform).Perform(self, oAttack, lVictim)
end

function CPerform:SkillFormulaEnv(oAttack,oVictim)
    local mRet = super(CPerform).SkillFormulaEnv(self, oAttack, oVictim)
    if oVictim then
        mRet.max_hp = oVictim:GetMaxHp()
    end
    return mRet
end
