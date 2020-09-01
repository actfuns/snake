local global = require "global"
local skynet = require "skynet"
local extend = require "base.extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local pfobj = import(service_path("perform/pfobj"))

function ChangeCmd(oAction)
    local cmd = {}
    cmd.cmd = "skill"
    cmd.data = {}
    local lPerform = oAction:GetPerformList()
    if  #lPerform > 0 then
        cmd.data.skill_id = lPerform[math.random(#lPerform)]
    end
    return cmd
end

function OnKickOut(oAttack)
    for _,w in pairs(oAttack:GetFriendList(true)) do
        local oBuffMgr = w.m_oBuffMgr
        local oBuff = oBuffMgr:HasBuff(129)
        if oBuff then
            oBuffMgr:RemoveBuff(oBuff)
        end
    end
end

function OnBoutEnd(oAction)
    if oAction:IsAlive() and oAction:GetMp() < oAction:GetMaxMp() * 10 // 100 then
        local mNet = {
            war_id = oAction:GetWarId(),
            content = "我需要补充法力！",
            wid = oAction:GetWid(),
        }
        oAction:SendAll("GS2CWarriorSpeek", mNet)
    end

    for _,w in pairs(oAction:GetFriendList(true)) do
        if w and w:IsPlayerLike() and w:IsAlive() and w:GetData("school") == gamedefines.PLAYER_SCHOOL.YAOCHI then
            if math.random(100) <= 25 then
                w:AddAura(1)
            end
        end
    end
end


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

function CPerform:GetProRatio(sAttr, oAttack)
    local mArgs = formula_string(self:ExtArg(), self:SkillFormulaEnv())
    local iRatio = mArgs[sAttr]
    if not iRatio then
        local mInfo = self:GetPerformData()
        local sFormula = mInfo["skill_formula"]
        iRatio = math.floor(formula_string(sFormula, self:SkillFormulaEnv()))    
    end
    return iRatio
end

function CPerform:IsDisabled(oAttack)
    local b = super(CPerform).IsDisabled(self, oAttack)
    if b then return true end

    for _,w in pairs(oAttack:GetFriendList(true)) do
        if w.m_bFlagWarrior and w.m_bFlagWarrior == 1402 then
            if oAttack:IsPlayer() then
                oAttack:Notify("本方同时只能存在一面杏黄旗")
            end
            return true
        end
    end

    local iPos = self:SelectSummonPos(oAttack)
    if not iPos and oAttack:IsPlayer() then
        oAttack:Notify("已达最大作战人数")
        return true
    end
    return false
end

function CPerform:TruePerform(oAttack, oVictim, iRatio)
    if not oAttack or oAttack:IsDead() then return end
        
    local iPos = self:SelectSummonPos(oAttack)
    if not iPos then return end

    local iRatio = 0
    if oAttack and oAttack:GetPerform(9505) then
        local oPerform = oAttack:GetPerform(9505)
        local sExtArg = oPerform:ExtArg()
        local mEnv = oPerform:SkillFormulaEnv(oAttack)
        local mExtArg = formula_string(sExtArg, mEnv)
        iRatio = mExtArg.attr_add_ratio or 0
    end

    local mInfo = {}
    mInfo.type = 1000
    mInfo.name = "杏黄旗"
    mInfo.model_info = {
        shape = 8214,
    }
    for _,k in pairs({"max_hp", "max_mp","phy_defense","mag_defense",
        "phy_hit_ratio","phy_hit_res_ratio", "mag_hit_ratio", "mag_hit_res_ratio",
        "phy_attack", "mag_attack", "speed", "cure_power"}) do
        mInfo[k] = math.floor(oAttack:GetData(k, 0) * self:GetProRatio(k, oAttack) / 100 * (100+iRatio) / 100)
    end
    mInfo.grade = math.floor(oAttack:GetData("grade", 0) * self:GetProRatio("grade") / 100)
    mInfo.hp = mInfo.max_hp
    mInfo.mp = mInfo.max_mp
    mInfo.perform = self:GetAllPerform()
    mInfo.perform_ai = mInfo.perform
    mInfo.aitype = 101
    mInfo.expertskill = oAttack:GetData("expertskill", {})

    local War = oAttack:GetWar()
    local oWarrior = War:AddNpcWarrior(oAttack:GetCampId(), mInfo, iPos, nil, true)
    oWarrior.m_bFlagWarrior = 1402
    oWarrior:Set("ignore_count", 1)
    oWarrior:AddFunction("ChangeCmd",1402, ChangeCmd)
    --oWarrior:AddFunction("OnKickOut",1402, OnKickOut)
    oWarrior:AddFunction("OnBoutEnd",1402, OnBoutEnd)

--    for _,w in pairs(oWarrior:GetFriendList(true)) do
--        local oBuffMgr = w.m_oBuffMgr
--        oBuffMgr:AddBuff(129,99,{
--            level = self:Level(),
--            grade = oAttack:GetGrade(),
--        })
--    end
end

function CPerform:GetAllPerform()
    local mPerform = {}
    mPerform[1408] = self:Level()
    return mPerform
end

function CPerform:SelectSummonPos(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end

    local iCamp = oAction:GetCampId()
    local lPosList = {11, 12, 13, 14}
    for _, iPos in ipairs(lPosList) do
        if not oWar:GetWarriorByPos(iCamp, iPos) then
            return iPos
        end
    end
end

function CPerform:NeedVictimTime()
    return false
end
