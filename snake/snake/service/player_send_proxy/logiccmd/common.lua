local global = require "global"

function DoAddSend(mRecord, mData)
    local oProxy = global.oProxy
    oProxy:DoAddSend(mData.mail, mData.message, mData.data)
end

function DoAddSendRaw(mRecord, mData)
    local oProxy = global.oProxy
    oProxy:DoAddSendRaw(mData.mail, mData.sdata)
end

function DoAddSendRawList(mRecord, mData)
    local oProxy = global.oProxy
    oProxy:DoAddSendRawList(mData.mail, mData.ldata)
end