
--import module

local global = require "global"
local skynet = require "skynet"

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
    local oActionMgr = global.oActionMgr
    local iDamage = math.floor(oVictim:GetMaxHp()/10)
    local oDHBuff = oAttack.m_oBuffMgr:HasBuff(177)
    if oDHBuff  and oDHBuff:GetDianHua() >0 then
        iDamage = math.floor(iDamage*(100+oDHBuff:GetDianHua()*10)/100)
    end
    oActionMgr:DoSubHp(oVictim,iDamage,oAttack)
    local oWar = oAttack:GetWar()
    if oWar then 
        local mCmd = {
                war_id = oWar:GetWarId(),
                speeks = {
                    {
                        wid = oAttack:GetWid(),
                        content = "凡尘尽断，方是大道！",
                    },
                },
                block_ms = 0,
                block_action = 0,
            }
        oWar:SendAll("GS2CWarriorSeqSpeek", mCmd)
    end
end
