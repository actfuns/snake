--import module
local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local record = require "public.record"

---------------------------delete---------------------------------
-- function SystemBehaviorType(mRecord, mData)
--     local oBehaviorObj = global.oBehaviorObj

--     local br,m = safe_call(oBehaviorObj.SystemBehaviorType, oBehaviorObj, mData)
--     if br then
--         interactive.Response(mRecord.source,mRecord.session,{errcode=0, data=m})
--     else
--         interactive.Response(mRecord.source,mRecord.session,{errcode=1, data={}})
--     end
-- end

-- function SystemBehavior(mRecord, mData)
--     local oBehaviorObj = global.oBehaviorObj

--     local br,m = safe_call(oBehaviorObj.SystemBehavior, oBehaviorObj, mData)
--     if br then
--         interactive.Response(mRecord.source,mRecord.session,{errcode=0, data=m})
--     else
--         interactive.Response(mRecord.source,mRecord.session,{errcode=1, data={}})
--     end
-- end

-- function StallBehavior(mRecord, mData)
--     local oBehaviorObj = global.oBehaviorObj

--     local br,m = safe_call(oBehaviorObj.StallBehavior, oBehaviorObj, mData)
--     if br then
--         interactive.Response(mRecord.source,mRecord.session,{errcode=0, data=m})
--     else
--         interactive.Response(mRecord.source,mRecord.session,{errcode=1, data={}})
--     end
-- end

-- function GameSysStatistics(mRecord, mData)
--     local oBehaviorObj = global.oBehaviorObj

--     local br,m = safe_call(oBehaviorObj.GameSysStatistics, oBehaviorObj, mData)
--     if br then
--         interactive.Response(mRecord.source,mRecord.session,{errcode=0, data={m}})
--     else
--         interactive.Response(mRecord.source,mRecord.session,{errcode=1, data={}})
--     end 
-- end

-- function OrgMemberStatistics(mRecord, mData)
--     local oBehaviorObj = global.oBehaviorObj

--     local br,m = safe_call(oBehaviorObj.OrgMemberStatistics, oBehaviorObj, mData)
--     if br then
--         interactive.Response(mRecord.source,mRecord.session,{errcode=0, data={m}})
--     else
--         interactive.Response(mRecord.source,mRecord.session,{errcode=1, data={}})
--     end 
-- end
