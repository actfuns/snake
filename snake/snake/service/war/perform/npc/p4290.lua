local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

--物理免疫
function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:Perform(oAttack, lVictim)
    local oWar = oAttack:GetWar()
    if oWar and #lVictim > 0 then
        local mNet = {
            war_id = oAttack:GetWarId(),
            speeks = {
                {
                    wid = oAttack:GetWid(),
                    content = "现在大家不用惧怕物理攻击啦",
                },
            },
            block_ms = 0,
            block_action = 0,
        }
        oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
    end
    super(CPerform).Perform(self, oAttack, lVictim)
end

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    self:Effect_Condition_For_Victim(oVictim,oAttack,{})
end