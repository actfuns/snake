--import module

local global = require "global"

local mSkillList = {}

function NewSkill(iSk)
    local oModule = import(service_path("partner/skill/skillobj"))
    local oSk = oModule.NewSkill(iSk)
    assert(oSk, string.format("partner NewSkill err: %d", iSk))
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

function LoadSkill(mData)
    local oSk = NewSkill(mData.sk)
    oSk:Load(mData)
    return oSk
end