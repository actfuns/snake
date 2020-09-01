local global = require "global"
local orgdefines = import(service_path("org.orgdefines"))
local achieveobj = import(service_path("org.achieveobj"))

local mBuildModule = {
    [101] = "buildhome",
    [102] = "buildshop",
    [103] = "buildhouse",
    [104] = "buildfane",
    [105] = "buildcash",
}

function NewBuild(iBid, iOrgID)
    local sModule = mBuildModule[iBid]
    assert(sModule, string.format("NewBuild err:%s", iBid))
    local sPath = string.format("org/build/%s", sModule)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("NewBuild err:%d", iBid))
    local oBuild = oModule.NewBuild(iBid, iOrgID)
    return oBuild
end

function LoadBuild(iBid, iOrgID, mData)
    local oBuild = NewBuild(iBid, iOrgID)
    oBuild:Load(mData)
    return oBuild
end

function GetBuildData(iBid)
    return {}
end

function NewAchieve(iType, iAch, iOrg)
    local func = orgdefines.NEW_ACH_FUNC[iType]
    assert(func, string.format("org NewAchieve err:%s", iType))
    local oAch = achieveobj[func](iAch, iOrg)
    return oAch
end

function LoadAchieve(iAch, iOrg, m)
    local res = require "base.res"
    local mData = res["daobiao"]["org"]["achieve"][iAch]
    assert(mData, string.format("org LoadAchieve err:%s", iAch))
    local iType = mData["type"]
    local oAch = NewAchieve(iType, iAch, iOrg)
    oAch:Load(m)
    return oAch
end