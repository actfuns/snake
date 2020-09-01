local global = require "global"
local extend = require "base/extend"


local mAIList = {}

function NewAI(iAI)
    local sPath = GetAIPath(iAI)
    local oModule = import(service_path(sPath))
    local oAI = oModule.NewAI(iAI)
    return oAI
end

function GetAI(iAI)
    local oAI = mAIList[iAI]
    if not oAI then
        oAI = NewAI(iAI)
        mAIList[iAI] = oAI
    end
    return oAI
end

function GetAIPath(iAI)
    if global.oDerivedFileMgr:ExistFile("ai", "ai"..iAI) then
        return string.format("ai/ai%d", iAI)
    end
    return "ai/aibase"
end
