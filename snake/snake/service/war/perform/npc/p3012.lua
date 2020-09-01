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
    if oVictim:GetName() ~="许仙" then
        record.error(string.format("%s perform %s  %s",oAttack:GetName(),self.m_ID,oVictim:GetName()))
        return
    end
    local oDHBuff = oVictim.m_oBuffMgr:HasBuff(177)
    if oDHBuff  then
        oDHBuff:AddDianHua(oVictim,-2)
    else
        local oGHBuff = oVictim.m_oBuffMgr:HasBuff(176)
        if not oGHBuff then
            oVictim.m_oBuffMgr:AddBuff(176,99,{point = 2})
        else
            oGHBuff:AddGanHua(oVictim,2)
        end
    end
    local oWar = oAttack:GetWar()
    if oWar then 
        local mCmd = {
                war_id = oWar:GetWarId(),
                speeks = {
                    {
                        wid = oAttack:GetWid(),
                        content = "官人，你快醒醒啊。",
                    },
                },
                block_ms = 0,
                block_action = 0,
            }
        oWar:SendAll("GS2CWarriorSeqSpeek", mCmd)
    end    
end

function CPerform:ChooseAITarget(oAttack)
    local lTarget = self:TargetList(oAttack)
    for _,oTarget in ipairs(lTarget) do
        if oTarget:GetName() == "许仙" then
            return oTarget:GetWid()
        end
    end
    return super(CPerform).ChooseAITarget(self,oAttack)
end
