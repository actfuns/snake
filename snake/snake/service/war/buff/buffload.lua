
local extend = require "base.extend"
local global = require "global"

local mLoadBuff = {101,103,110,117,123, 134, 135, 136, 139}

local mBuffList = {}

function GetPath(iBuffID)
    if global.oDerivedFileMgr:ExistFile("buff", "b"..iBuffID) then
        return string.format("buff/b%d", iBuffID)
    end
    return "buff/buffbase"
end

function NewBuff(iBuffID)
    local sPath = GetPath(iBuffID)
    local oModule = import(service_path(sPath))
    local oBuff = oModule.NewBuff(iBuffID)
    return oBuff
end

function GetBuff(iBuffID)
    local oBuff = mBuffList[iBuffID]
    if oBuff then
        return oBuff
    end
    oBuff = NewBuff(iBuffID)
    mBuffList[iBuffID] = oBuff
    return oBuff
end
