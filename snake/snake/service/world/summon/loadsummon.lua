local res = require "base.res"

SummonList = {}

function CreateSummon(sid, ...)
    local oModule = import(service_path("summon.summobj"))
    local oSummon = oModule.NewSummon(sid)
    oSummon:Create(...)
    return oSummon
end

function CreateCombineSummon(sid, oSummon1, oSummon2, iLimitGrade, ...)
    local oModule = import(service_path("summon.summobj"))
    local oSummon = oModule.NewSummon(sid)
    local iPoint = oSummon:CreateCombine(oSummon1, oSummon2, iLimitGrade, ...)
    return oSummon, iPoint
end

function CreateFixedPropSummon(sid, idx, ...)
    local oModule = import(service_path("summon.summobj"))
    local oSummon = oModule.NewSummon(sid)
    oSummon:CreateFixedProp(idx, ...)
    return oSummon
end

function CreateSepWashSummon(sid, ...)
    local oModule = import(service_path("summon.summobj"))
    local oSummon = oModule.NewSummon(sid)
    oSummon:CreateSepWashSummon(...)
    return oSummon
end

function GetSummon(sid)
    local oSummon = SummonList[sid]
    if not oSummon then
        oSummon = CreateSummon(sid)
        SummonList[sid] = oSummon
    end
    return oSummon
end

function LoadSummon(sid, data)
    local oModule = import(service_path("summon.summobj"))
    local oSummon = oModule.NewSummon(sid)
    oSummon:Load(data)
    oSummon:Setup()
    return oSummon
end

function GetTaskSubmitableSummonGroup(oPlayer, iSummGroupId)
    local lGroupSids = table_get_depth(res, {"daobiao", "summon", "summongroup", iSummGroupId, "sids"})
    if not lGroupSids then
        return {}
    end
    local iPlayerGrade = oPlayer:GetGrade()
    local mSummonInfo = table_get_depth(res, {"daobiao", "summon", "info"})
    local lSids = {}
    for idx, sid in ipairs(lGroupSids) do
        local iNeedGrade = table_get_depth(mSummonInfo, {sid, "carry"})
        if not iNeedGrade or iNeedGrade <= iPlayerGrade then
            table.insert(lSids, sid)
        end
    end
    return lSids
end

function GetSummonNameBySid(sid)
    local mSummonInfo = table_get_depth(res, {"daobiao", "summon", "info", sid})
    if not mSummonInfo then
        return ""
    end
    return mSummonInfo.name or ""
end
