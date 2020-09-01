

--import module

local global = require "global"
local skynet = require "skynet"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

--天佛降世

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:CalWarrior(oAction, oPerformMgr)
    local iPerform = self:Type()
    local func = function(oAction)
        OnNewBout(iPerform, oAction)
    end
    oPerformMgr:AddFunction("OnNewBout", self.m_ID, func)

    local func1 = function(oAttack, oVictim, oPerform)
        return CalActionHit(oAttack, oVictim, oPerform)
    end
    oPerformMgr:AddFunction("CalActionHit", self.m_ID, func1)
end

function CPerform:Perform(oAttack, lVictim)
    if oAttack:IsNpcLike() and oAttack:GetCampId() == 2 then
        local oWar = oAttack:GetWar()
        oWar:SendAll("GS2CWarriorSeqSpeek", {
            war_id = oAttack:GetWarId(),
            speeks = {
                {
                    wid = oAttack:GetWid(),
                    content = "天佛佑我，金刚不破！",
                },
            },
            block_ms = 0,
            block_action = 0,
        })
    end
    super(CPerform).Perform(self, oAttack, lVictim)
end

function CPerform:NeedVictimTime()
    return false
end

function OnNewBout(iPerform, oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end

    if oWar:CurBout() % 2 ~= 1 then return end

    local oPerform = oAction:GetPerform(iPerform)
    if oPerform then
        oPerform:Perform(oAction, {oAction})
    end
end


function CalActionHit(oAttack, oVictim, oPerform)
    if not oPerform or oPerform:Type() ~= 3010 then
        return 0
    end
    if oAttack:GetWid() ~= oVictim:GetWid() then
        return 0
    end
    return 10000
end

