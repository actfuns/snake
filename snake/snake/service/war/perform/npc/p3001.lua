--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--财迷的愤怒

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
                    content = "对付进塔参观不买门票的人就一条…狠狠打",
                },
            },
            block_ms = 0,
            block_action = 0,
        }
        oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
    end
    super(CPerform).Perform(self, oAttack, lVictim)
end
