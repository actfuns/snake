local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"

function WriteData(mRecord, mData)
    local oLogFileObj = global.oLogFileObj
    oLogFileObj:WriteData(mData.sName, mData.data)
end

function WriteMtbi(mRecord, mData)
    local oLogFileObj = global.oLogFileObj
    oLogFileObj:WriteMtbi(mData.sName, mData.data) 
end

function WriteDb2File(mRecord, mData)
    local oLogFileObj = global.oLogFileObj
    oLogFileObj:WriteDb2File(mData.key, mData.data) 
end
