--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"

function GetPlayerDetailInfo(mRecord, mData)
    local oBusinessObj = global.oBusinessObj
    local iShowId = mData["playerId"]
    oBusinessObj:GetPlayerDetailInfo(mData, function(mRet)
        interactive.Response(mRecord.source, mRecord.session, mRet)
    end)
end

-- function currencyQuery(mRecord, mData)
--     local oBusinessObj = global.oBusinessObj

--     local br, m = safe_call(oBusinessObj.CurrencyQuery, oBusinessObj, mData)
--     if br then
--         interactive.Response(mRecord.source, mRecord.session, {
--             errcode = m.errcode,
--             data = m.data,
--         })
--     else
--         interactive.Response(mRecord.source, mRecord.session, {
--             errcode = 1,
--         })
--     end
-- end

function GetOrgInfoList(mRecord, mData)
    global.oBusinessObj:GetOrgInfoList(mData, function (mRet)
        interactive.Response(mRecord.source, mRecord.session, mRet)            
    end)    
end

function GetOrgMemberList(mRecord, mData)
    global.oBusinessObj:GetOrgMemberList(mData, function (mRet)
        interactive.Response(mRecord.source, mRecord.session, mRet)            
    end)    
end


