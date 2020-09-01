--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))


function NewCPerform(...)
    local o = CPerform:New(...)
    return o
end

CPerform = {}
CPerform.__index = CPerform
inherit(CPerform, pfobj.CPerform)

function CPerform:TruePerform(oAttack,oVictim,iRatio)
    if not oVictim:IsPlayerLike() then return end

    local oWar = oAttack:GetWar()
    local sExtArg = self:ExtArg()
    local mExtArg = formula_string(sExtArg, {})
    local sKey = table_choose_key(mExtArg)

    local iVal = formula_string(sKey, {lv=oVictim:GetGrade()})
    local iSilver = oVictim:GetData("silver", 0)
    local iSteal = math.min(iVal, iSilver)
    oWar:AddWarBackArgs("steal_silver", iSteal)
    oVictim:SetData("silver", iSilver - iSteal)

    local sContent = "偷盗失败"
    if iSteal > 0 then
        sContent = string.format("偷取了%s两银币", iSteal)
    end

    local mNet = {
        war_id = oWar:GetWarId(),
        speeks = {
            {wid=oAttack:GetWid(), content=sContent}
        },
        block_ms = 0,
        block_action = 0,
    }
    oWar:SendAll("GS2CWarriorSeqSpeek", mNet)
end
