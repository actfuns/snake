--import module

local global = require "global"
local skynet = require "skynet"
local record = require "public.record"

local loadskill = import(service_path("skill/loadskill"))
local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))

function C2GSLearnSkill(oPlayer, mData)
    local sType = mData["type"]
    local iSkill = mData["sk"]
    local iFlag = mData["flag"]

    local oToolMgr = global.oToolMgr
    if sType == "active" then
        if not oToolMgr:IsSysOpen("SKILL_ZD", oPlayer) then return end
    elseif sType == "passive" then
        if not oToolMgr:IsSysOpen("SKILL_BD", oPlayer) then return end
    end

    local oPubMgr = global.oPubMgr
    local oLearnSkill = oPubMgr:GetLearnSkillObj(sType)
    if oLearnSkill then
        oLearnSkill:Learn(oPlayer,iSkill, iFlag)
    end
end

function C2GSFastLearnSkill(oPlayer,mData)
    local sType = mData["type"]

    local oToolMgr = global.oToolMgr
    if sType == "active" then
        if not oToolMgr:IsSysOpen("SKILL_ZD", oPlayer) then return end
    elseif sType == "passive" then
        if not oToolMgr:IsSysOpen("SKILL_BD", oPlayer) then return end
    end

    local oPubMgr = global.oPubMgr
    local oLearnSkill = oPubMgr:GetLearnSkillObj(sType)
    if oLearnSkill then
        oLearnSkill:FastLearn(oPlayer)
    end
end

function C2GSResetActiveSchool(oPlayer,mData)
    do return end
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("SKILL_ZD", oPlayer) then return end

    local iSkill = mData["sk"]
    local oPubMgr = global.oPubMgr
    local oLearnSkill = oPubMgr:GetLearnSkillObj("active")
    if not oLearnSkill then
        return
    end
    oLearnSkill:ResetSkill(oPlayer,iSkill)
end

function C2GSLearnCultivateSkill(oPlayer, mData)
    local iType = mData["type"]
    local iSkill = mData["sk"]
    oPlayer.m_oSkillCtrl:C2GSLearnCultivateSkill(iType,iSkill)
end

function C2GSSetCultivateSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("XIU_LIAN_SYS", oPlayer) then return end

    local iSkill = mData["sk"]
    oPlayer.m_oSkillCtrl:SetCultivateSkillID(iSkill)
    local mLog = oPlayer:LogData()
    mLog["skid"] = iSkill
    record.log_db("playerskill", "set_cultivate_skill", mLog)
end

function C2GSLearnOrgSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local iSkill = mData["sk"]
    local oSKill = oPlayer.m_oSkillCtrl:GetOrgSkillById(iSkill)
    if not oSKill then return end

    oSKill:Learn(oPlayer)
end

-- 使用帮派技能
function C2GSUseOrgSkill(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local iSkill = mData["sk"]
    local oSKill = oPlayer.m_oSkillCtrl:GetOrgSkillById(iSkill)
    if not oSKill then return end

    oSKill:Use(oPlayer, mData["args"])
end

function C2GSLearnFuZhuanSkill(oPlayer,mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("FUZHUAN", oPlayer) then return end
    local iSkill = mData["sk"]
    local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(iSkill)
    if not oSKill then return end
    oSKill:Learn(oPlayer)
end

function C2GSResetFuZhuanSkill(oPlayer,mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("FUZHUAN", oPlayer) then return end
    local iSkill = mData["sk"]
    local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(iSkill)
    if not oSKill then return end
    oSKill:Reset(oPlayer)
end

function C2GSProductFuZhuanSkill(oPlayer,mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("FUZHUAN", oPlayer) then return end
    local iSkill = mData["sk"]
    local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(iSkill)
    if not oSKill then return end
    oSKill:Product(oPlayer)
end

function C2GSEnergyExchangeSilver(oPlayer, mData)
    local oSkillCtrl = oPlayer.m_oSkillCtrl
    if oSkillCtrl then
        oSkillCtrl:C2GSEnergyExchangeSilver(oPlayer)
    end
end