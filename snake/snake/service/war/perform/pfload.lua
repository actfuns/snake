local global = require "global"
local extend = require "base/extend"
local pfobj = import(service_path("perform.pfobj"))

local PerformList = {}

local PerformDir = {
    ["school"]  = {1001,2999},
    ["summon"] = {5101,5800},
    ["ride"] = {5900,6000},
    ["partner"] = {7100, 8400},
    ["se"] = {9000, 9500},
    ["npc"] = {3000, 4300},
    ["marry"] = {8500, 8599},
    ["fabao"] = {4600, 4800},
    ["artifact"] = {9501, 9600},
}

function GetPerformDir(sid)
    for sDir,mPos in pairs(PerformDir) do
        local iStart,iEnd = table.unpack(mPos)
        if iStart <= sid and sid <= iEnd then
            return sDir
        end
    end
end

function GetPerformClass(iPerform)
    local res = require "base.res"
    local mPfInfo = res["daobiao"]["perform"][iPerform]
    assert(mPfInfo, string.format("GetPerformClass err:%d", iPerform))
    return mPfInfo["pflogic"]
end

function NewPerform(iPerform)
    iPerform = tonumber(iPerform)
    local iPFClass = GetPerformClass(iPerform)
    local sDir = GetPerformDir(iPFClass)
    if global.oDerivedFileMgr:ExistFile("perform", sDir, "p"..iPFClass) then
        local sPath = string.format("perform/%s/p%d",sDir,iPFClass)
        local oModule = import(service_path(sPath))
        return oModule.NewCPerform(iPerform)
    else
        return pfobj.NewCPerform(iPerform)
    end
end

function GetPerform(iPerform,...)
    iPerform = tonumber(iPerform)
    local oPerform = PerformList[iPerform]
    if oPerform then
        return oPerform
    end
    assert(iPerform,string.format("GetPerform err:%s",iPerform))
    local oPerform = NewPerform(iPerform)
    PerformList[iPerform] = oPerform
    return oPerform
end
