--import module

local global = require "global"

local mSkillList = {}

function NewSkill(iSk, lv)
    local oModule = import(service_path("summon/skill/skillbase"))
    local oSk = oModule.NewSkill(iSk)
    assert(oSk, string.format("summon NewSkill err: %d", iSk))
    oSk:SetLevel(lv)
    return oSk
end

function GetSkill(iSk)
    local oSk = mSkillList[iSk]
    if oSk then
        return oSk
    end
    local oSk = NewSkill(iSk)
    mSkillList[iSk] = oSk
    return oSk
end

function LoadSkill(iSk,mData)
    local oSk = NewSkill(iSk)
    oSk:Load(mData)
    return oSk
end