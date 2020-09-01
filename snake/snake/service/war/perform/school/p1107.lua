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

function CPerform:New(pfid)
    local o = super(CPerform).New(self,pfid)
    return o
end

function CPerform:SelfValidCast(oAttack,oVictim)
    --[[
    if oAttack:IsPlayer() and oAttack:GetAura() < 3 then
        return false
    end
    ]]
    return true
end

function CPerform:CalAttackRatio(oAttack)
    local mEnv = {
        hp = oAttack:GetHp(),
        maxhp = oAttack:GetMaxHp()
    }
    local sExtArgs = self:ExtArg()
    local mArgs = formula_string(sExtArgs,mEnv)
    return mArgs["attack_ratio"]
end

function CPerform:Perform(oAttack,lVictim)
    local oVictim = lVictim[math.random(#lVictim)]
    if not oVictim then
        return
    end
    local oActionMgr = global.oActionMgr
    local iAttackCnt = 4
    for i=1,3 do
        local iRatio = 30 + self:CalAttackRatio(oAttack)
        if math.random(100) <= iRatio then
            iAttackCnt = iAttackCnt + 1
        end
    end 
    self:PerformPhyAttack(oAttack, oVictim, 100, iAttackCnt)
    self:EndPerform(oAttack, lVictim)
end

--招式特殊定制 
function CPerform:PerformPhyAttack(oAttack, oVictim, iDamageRatio, iAttackCnt)
    local oWar = oAttack:GetWar()

    for i=1, iAttackCnt do
        if not oAttack or oAttack:IsDead() then
            break
        end
        if not oVictim or oVictim:IsDead() then
            break
        end
        if i < 5 then
            oAttack:SendAll("GS2CWarSkill", {
                war_id = oAttack:GetWarId(),
                action_wlist = {oAttack:GetWid(),},
                select_wlist = {oVictim:GetWid()},
                skill_id = self:Type(),
                magic_id = i,
            })
            local mTime = self:PerformMagicTime(oAttack, i)
            oWar:AddAnimationTime(mTime[1])
        else
            oAttack:SendAll("GS2CWarSkill", {
                war_id = oAttack:GetWarId(),
                action_wlist = {oAttack:GetWid(),},
                select_wlist = {oVictim:GetWid()},
                skill_id = self:Type(),
                magic_id = 5,
            })

            local mTime = self:PerformMagicTime(oAttack, 5)
            if i == iAttackCnt then
                oWar:AddAnimationTime(mTime[2])
            else
                oWar:AddAnimationTime(mTime[1])
            end
        end

        local iAttackCnt = self:GetData("PerformAttackCnt",0)
        iAttackCnt = iAttackCnt + 1
        self:SetData("PerformAttackCnt", iAttackCnt)
        global.oActionMgr:TryDoPhyAttack(oAttack, oVictim, self, iDamageRatio)
    end
    self:SetData("PerformAttackCnt",nil)
    local iAttackedTime = oVictim:GetAttackedTime()
    oWar:AddAnimationTime(iAttackedTime)
    oWar:AddAnimationTime(600)
    oAttack:SendAll("GS2CWarGoback", {
        war_id = oAttack:GetWarId(),
        action_wid = oAttack:GetWid(),
    })
end

