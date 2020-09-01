
--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--秘方封印

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)


function CPerform:Perform(oAttack, lVictim)
    local iType = oAttack:GetData("type")
    local oWar = oAttack:GetWar()
    if iType == 3001 and oWar then
        local mNet = {
            war_id = oWar:GetWarId(),
            speeks = {
                {
                    content = "没有#G金山寺#n、#G青城山#n、#G瑶池#n的弟子，让你们领教我的厉害",
                    wid = oAttack:GetWid(),
                },
            },
            block_ms = 0,
            block_action = 0,
        }
        oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
    end
    super(CPerform).Perform(self, oAttack, lVictim)
end

function CPerform:CalWarrior(oAction, oPerformMgr)
    local func = function(oAttack, oVictim, oPerform)
        return OnSealRatio(oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("OnSealRatio", self.m_ID, func)
end

function OnSealRatio(oAttack, oVictim, oPerform)
    if not oPerform or oPerform:Type() ~= 3011 then
        return 0
    end
    return 10000
end
