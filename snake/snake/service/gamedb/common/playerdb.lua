--import module
local global = require "global"
local skynet = require "skynet"
local mongoop = require "base.mongoop"
local interactive = require "base.interactive"

local sPlayerTableName = "player"

function GetPlayer(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid}, {pid = true, name = true, account = true, channel = true, create_time = true, base_info = true, ban_time=true, deleted = true, platform = true, born_server = true, deleted = true, now_server = true})
    return {
        data = m,
        pid = mCond.pid,
    }
end

function GetPlayerByName(mCond, mData)
    local sName = mCond.name
    local br, m = safe_call(function ()
        local oGameDb = global.oGameDb
        return oGameDb:FindOne(sPlayerTableName, {name = sName}, {pid = true, account = true, channel = true, base_info = true, deleted = true})
    end)
    
    local mRet
    if br then
        mRet = {data = m, pid = m and m.pid}
    else
        mRet = {err = 1, name = sName}
    end
    return mRet
end

function CreatePlayer(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Insert(sPlayerTableName, mData.data)
end

function RemovePlayer(mCond, mData)
    local oGameDb = global.oGameDb
    local ok, err = oGameDb:Update(sPlayerTableName, {pid = mCond.pid}, {["$set"] = {deleted = 1}})
    return {ok = ok, err = err}
end

function GetPlayerListByAccount(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sPlayerTableName, {account = mCond.account, channel = mCond.channel, platform = mCond.platform}, {pid = true, name = true, account = true, base_info = true, deleted = true, born_server = true})
    local mRet = {}
    while m:hasNext() do
        table.insert(mRet, m:next())
    end
    return {
        data = mRet,
        account = mCond.account,
        channel = mCond.channel
    }
end

function LoadPlayerMain(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid}, {name = true, now_server = true})
    return {
        data = m,
        pid = mCond.pid,
    }
end

function SavePlayerMain(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid = mCond.pid}, {["$set"]=mData.data})
end

function LoadPlayerBase(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid}, {base_info = true})
    return {
        data = m.base_info,
        pid = mCond.pid,
    }
end

function SavePlayerBase(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid = mCond.pid}, {["$set"]={base_info = mData.data}})
end

function LoadPlayerActive(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid}, {active_info = true})
    return {
        data = m.active_info,
        pid = mCond.pid,
    }
end

function SavePlayerActive(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid = mCond.pid}, {["$set"]={active_info = mData.data}})
end

function LoadPlayerItem(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{item_info = true})
    return {
        data = m.item_info,
        pid = mCond.pid,
     }
end

function SavePlayerItem(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={item_info=mData.data}})
end

function LoadPlayerTimeInfo(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{time_info = true})
    return {
        data = m.time_info,
        pid = mCond.pid,
     }
end

function SavePlayerTimeInfo(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={time_info=mData.data}})
end

function LoadPlayerTask(mCond,mData)
   local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{task_info = true})
    return {
        data = m.task_info,
        pid = mCond.pid,
    }
end

function SavePlayerTaskInfo(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={task_info=mData.data}})
end

function LoadPlayerWareHouse(mCond,mData)
   local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{wh_info = true})
    return {
        data = m.wh_info,
        pid = mCond.pid,
    }
end

function SavePlayerWareHouse(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={wh_info=mData.data}})
end

function LoadSkillInfo(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{skill_info = true})
    return {
        data = m.skill_info,
        pid = mCond.pid,
    }
end

function SaveSkillInfo(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={skill_info=mData.data}})
end

function LoadPlayerSummon(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{summon_info = true})
    return {
        data = m.summon_info,
        pid = mCond.pid,
    }
end

function SavePlayerSummon(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={summon_info=mData.data}})
end

function LoadPlayerSchedule(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{schedule_info = true})
    return {
        data = m.schedule_info,
        pid = mCond.pid,
     }
end

function SavePlayerSchedule(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={schedule_info=mData.data}})
end

function LoadPlayerState(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{state_info = true})
    return {
        data = m.state_info,
        pid = mCond.pid,
     }
end

function SavePlayerState(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={state_info=mData.data}})
end

function LoadPlayerPartner(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{partner_info = true})
    return {
        data = m.partner_info,
        pid = mCond.pid,
     }
end

function SavePlayerPartner(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={partner_info = mData.data}})
end

function LoadPlayerTitle(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{title_info = true})
    return {
        data = m.title_info,
        pid = mCond.pid,
     }
end

function LoadPlayerTouxian(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{touxian_info = true})
    return {
        data = m.touxian_info,
        pid = mCond.pid,
     }
end

function SavePlayerTitle(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={title_info = mData.data}})
end

function SavePlayerTouxian(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={touxian_info = mData.data}})
end

function LoadPlayerAchieve(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{achieve_info = true})
    return {
        data = m.achieve_info,
        pid = mCond.pid,
     }
end

function SavePlayerAchieve(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={achieve_info = mData.data}})
end

function LoadPlayerRide(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{ride_info = true})
    return {
        data = m.ride_info,
        pid = mCond.pid,
     }
end

function SavePlayerRide(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={ride_info = mData.data}})
end

function LoadPlayerTempItem(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{tempitem_info = true})
    return {
        data = m.tempitem_info,
        pid = mCond.pid,
     }
end

function SavePlayerTempItem(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={tempitem_info=mData.data}})
end

function LoadPlayerRecovery(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{recovery_info = true})
    return {
        data = m.recovery_info,
        pid = mCond.pid,
     }
end

function SavePlayerRecovery(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={recovery_info=mData.data}})
end

function LoadPlayerEquip(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid},{equip_info = true})
    return {
        data = m.equip_info,
        pid = mCond.pid,
     }
end

function SavePlayerEquip(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={equip_info=mData.data}})    
end

function LoadPlayerStore(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName, {pid = mCond.pid},{store_info = true})
    return {
        data = m.store_info,
        pid = mCond.pid,
     }
end

function SavePlayerStore(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={store_info=mData.data}})
end

function LoadPlayerSummonCk(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{summon_ck_info = true})
    return {
        data = m.summon_ck_info,
        pid = mCond.pid,
    }
end

function SavePlayerSummonCk(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={summon_ck_info=mData.data}})
end

function LoadPlayerFaBao(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{fabao_info = true})
    return {
        data = m.fabao_info,
        pid = mCond.pid,
     }
end

function SavePlayerFaBao(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={fabao_info = mData.data}})
end

function LoadPlayerArtifact(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{artifact_info = true})
    return {
        data = m.artifact_info,
        pid = mCond.pid,
    }
end

function SavePlayerArtifact(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={artifact_info=mData.data}})
end

function LoadPlayerWing(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{wing_info = true})
    return {
        data = m.wing_info,
        pid = mCond.pid,
    }
end

function SavePlayerWing(mCond,mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName,{pid=mCond.pid},{["$set"]={wing_info=mData.data}})
end

function LoadPlayerMarryInfo(mCond, mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:FindOne(sPlayerTableName,{pid = mCond.pid},{marry_info = true})
    return {
        data = m.marry_info,
        pid = mCond.pid,
     }
end

function SavePlayerMarryInfo(mCond, mData)
    local oGameDb = global.oGameDb
    oGameDb:Update(sPlayerTableName, {pid=mCond.pid}, {["$set"]={marry_info = mData.data}})
end

function GetConflictNamePlayer(mCond,mData)
    local oGameDb = global.oGameDb
    local m = oGameDb:Find(sPlayerTableName, {}, {pid = true, name = true, now_server = true})
    local mPlayers = {}
    local mRet = {}
    while m:hasNext() do
        local mInfo = m:next()
        local sName = mInfo.name
        local mNameInfo = mPlayers[sName]
        if not mNameInfo then
            mPlayers[sName] = mInfo
        else
            if mNameInfo.now_server and mNameInfo.now_server ~= get_server_tag() then
                mPlayers[sName] = mInfo
                mRet[mNameInfo.pid] = sName
            elseif mInfo.now_server and mInfo.now_server ~= get_server_tag() then
                mRet[mInfo.pid] = sName
            end
        end
    end
    return mRet
end
