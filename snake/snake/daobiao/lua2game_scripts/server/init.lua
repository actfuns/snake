local string = string
local extend = require "tools.lua.extend"

local dumpapi = require "utils.datadump"

local sRootPath, sOutPath = ...

local function table_key_list(t)
    local l = {}
    for k, v in pairs(t) do
        table.insert(l, k)
    end
    return l
end

local function table2string(t)
    return extend.Table.serialize(t)
end

local function formula_string(s, m)
    local f = load(string.format([[
        return function (m)
            for k, v in pairs(m) do
                _ENV[k] = v
            end
            return (%s)
        end]], s), s, "bt", {pairs = pairs,math=math})()
    return f(m)
end

local function split_string(s, rep, f, bReg)
    assert(rep ~= '')
    local lst = {}
    if #s > 0 then
        local bPlain
        if bReg then
            bPlain = false
        else
            bPlain = true
        end

        local iField, iStart = 1, 1
        local iFirst, iLast = string.find(s, rep, iStart, bPlain)
        while iFirst do
            lst[iField] = string.sub(s, iStart, iFirst - 1)
            iField = iField + 1
            iStart = iLast + 1
            iFirst, iLast = string.find(s, rep, iStart, bPlain)
        end
        lst[iField] = string.sub(s, iStart)

        if f then
            for k, v in ipairs(lst) do
                lst[k] = f(v)
            end
        end
    end
    return lst
end

local function exist_file(sFile)
    local f = io.open(sFile)
    if not f then
        return false
    end
    f:close()
    return true
end
-----------------------------------

local USE_TMP_VERSION = true

local function SafeRequire(sPath)
    local sFile = string.format("%s/tmp/%s.lua", sRootPath, sPath)
    if not USE_TMP_VERSION or not exist_file(sFile) then
        sFile = string.format("%s/%s.lua", sRootPath, sPath)
    end
    local f, s = loadfile(sFile, "bt")
    if not f then
        return nil, s
    end
    return f()
end

local function Require(sPath)
    local t, s = SafeRequire(sPath)
    assert(t, s)
    return t
end

local mAllNpcTypes = {}
local function CheckRecNpcTypes(mNpcTbl, sTblName)
    for npctype, _ in pairs(mNpcTbl) do
        local x = mAllNpcTypes[npctype]
        if not x then
            mAllNpcTypes[npctype] = sTblName
        elseif type(x) == "string" then
            mAllNpcTypes[npctype] = {x, sTblName}
        elseif type(x) == "table" then
            table.insert(x, sTblName)
        end
    end
end

local function CheckRaiseNpcTypes()
    local lErrMsg = {}
    for npctype, x in pairs(mAllNpcTypes) do
        if type(x) == "table" then
            table.insert(lErrMsg, string.format("表%s使用重复的npc id字段%d", table.concat(x, "、"), npctype))
        end
    end
    if #lErrMsg > 0 then
        print(string.format("npc表id填写不合规范：\n%s", table.concat(lErrMsg, "\n")))
        -- assert(false)
    end
end

local function RequireItem()
    local mFile = {"itemother","itemvirtual","equip","summskill","shenhun","fu",
    "equipbook", "partner", "partnerequip", "totask", "giftpack", "box", "summon", "summonequip", "wenshi"}
    local ret = {}
    for _,sFile in pairs(mFile) do
        local m = Require(string.format("item/%s",sFile))
        for id,mData in pairs(m) do
            ret[id] = mData
        end
    end
    return ret
end

local function RequireDazao()
    local ret = {}
    local m = Require("item/equipbook")
    for id, mData in pairs(m) do
        ret[id] = {id=mData["id"], level=mData["level"], sex=mData["sex"], school=mData["school"]}
    end
    return ret
end

local function RequireHunShi()
    local mResult = {}
    local mColor = Require("item/hunshi_color")
    local mRatio = Require("item/hunshi_combineratio")
    local mLianHua = Require("item/hunshi_lianhua")
    local equiplimit = Require("item/hunshi_equiplimit")
    local equipcolor = Require("item/hunshi_equipcolor")
    local mAttr = {}
    local mSid2Color = {}
    for iColor,mInfo in pairs(mColor) do
        mSid2Color[mInfo.itemsid] = iColor
    end
    for _,mInfo in pairs(Require("item/hunshi_attr")) do 
        local iColor = mInfo.color
        local sAttr = mInfo.attr
        if not mAttr[iColor] then 
            mAttr[iColor] = {}
        end 
        mAttr[iColor][sAttr] = mInfo
    end 
    mResult.color = mColor
    mResult.ratio = mRatio
    mResult.lianhua = mLianHua
    mResult.attr = mAttr
    mResult.sid2color = mSid2Color
    mResult.equiplimit = equiplimit
    mResult.equipcolor = equipcolor
    return mResult
end

local function RequireWenShi()
    local mResult = {}
    mResult.grade_config = Require("item/grade_config")
    mResult.color_config = Require("item/color_config")
    mResult.attr_list = Require("item/attr_list")
    mResult.skill_list = Require("item/skill_list")
    mResult.wenshi_combine = Require("item/wenshi_combine")
    return mResult
end

local function RequireEquipLevels(mItems)
    local mEquipLvs = {}
    for iSid, mItemInfo in pairs(mItems) do
        local iEquipLv = mItemInfo.equipLevel
        if iEquipLv and type(iEquipLv) == "number" then
            mEquipLvs[iEquipLv] = 1
        end
    end
    local lLvs = table_key_list(mEquipLvs)
    table.sort(lLvs)
    return lLvs
end

local function RequireWeapon()
    local mRet = {}
    local mData = Require("item/equip")
    for sid,m in pairs(mData) do
        if m["equipPos"] == 1 then
            local iRole = m["roletype"]
            local mSid = mRet[iRole]
            if not mSid then
                mSid = {}
                mRet[iRole] = {}                
            end
            mSid[m["equipLevel"]] = sid
        end
    end
    return mRet
end

local function RequireTaskDialog(sPath)
    local m = SafeRequire(sPath)
    local ret = {}
    local mDialog = {}
    for _,mData in pairs(m) do
        local dialog_id = mData["dialog_id"]
        local subid = mData["subid"]
        if not mDialog[dialog_id] then
            mDialog[dialog_id] = {}
        end
        mDialog[dialog_id][subid] = {type=mData["type"],preId=mData["preId"],content=mData["content"],voice=mData["voice"],timeout=mData["timeout"]}
    end
    for dialog_id,mData in pairs(mDialog) do
        ret[dialog_id] = {
            id = dialog_id,
            Dialog = mData
        }
    end
    return ret
end

local function RequireItemReward(sPath)
    local m = Require(sPath)
    local ret = {}
    local mItemReward = {}
    for _,mData in pairs(m) do
        local itemid = mData["idx"]
        if not ret[itemid] then
            ret[itemid] = {}
        end
        table.insert(ret[itemid],mData)
    end
    return ret
end

local function RequireSummonReward(sPath)
    local m = Require(sPath)
    local ret = {}
    local mItemReward = {}
    for _,mData in pairs(m) do
        local itemid = mData["idx"]
        if not ret[itemid] then
            ret[itemid] = {}
        end
        table.insert(ret[itemid],mData)
    end
    return ret
end

local function RequireItemRewardGroupIdxed(sPath)
    local mItemReward = RequireItemReward(sPath)
    local ret = {}
    for idx, mGroup in pairs(mItemReward) do
        local mGroupAlter = {}
        for _, mData in pairs(mGroup) do
            local iGroupIdx = mData.groupidx
            assert(iGroupIdx, sPath .. "需要填写groupidx")
            mGroupAlter[iGroupIdx] = mData
        end
        ret[idx] = mGroupAlter
    end
    return ret
end

local function RequireItemFilter(sPath)
    local mItemFilter = RequireItemReward(sPath)
    for idx, mItemData in pairs(mItemFilter) do
        for groupidx, mData in pairs(mItemData) do
            if mData.sex == 0 then
                mData.sex = nil
            end
            if mData.roletype == 0 then
                mData.roletype = nil
            end
            -- assert(mData.sex or mData.roletype, sPath .. " filter condition null, " .. idx .. "->" .. groupidx)
        end
    end
    return mItemFilter
end

local function RequireNPCStore(sPath)
    local m = SafeRequire(sPath)
    local index = {}
    local sid2id = {}
    for id, mData in pairs(m) do
        local iShopId = mData.shop_id
        index[iShopId] = index[iShopId] or {}
        local iTag = mData.tag_id
        index[iShopId][iTag] = index[iShopId][iTag] or {}
        table.insert(index[iShopId][iTag], id)
        
        if not sid2id[iShopId] then sid2id[iShopId] = {} end
        sid2id[iShopId][mData.item_id] = id        
    end
    return {data = m, index = index, sid2id = sid2id}
end

local function RequirePerformLogic()
    local mPath = {"pflogic_school","pflogic_summon","pflogic_partner","pflogic_npc","pflogic_se", "pflogic_ride", "pflogic_marry","pflogic_artifact","pflogic_fabao"}
    local mData = {}
    for _,sPath in pairs(mPath) do
        local m = SafeRequire(string.format("perform/%s", sPath))
        for id,mPerformLogic in pairs(m) do
            mData[id] = mPerformLogic
        end
    end
    return mData
end

local function RequirePerform()
    local mLogic = RequirePerformLogic()
    local mPath = {"school","sumperform","summon_passive","partner","npc","se","ride","marry","artifact","fabao"}
    local mData = {}
    for _,sPath in pairs(mPath) do
        local m = SafeRequire(string.format("perform/%s" ,sPath))
        for id,mPerformData in pairs(m) do
            if mPerformData["pflogic"] then
                local iLogic = mPerformData["pflogic"]
                assert(iLogic and mLogic[iLogic], string.format("RequirePerform %d pflogic err", id))
                for k,v in pairs(mLogic[iLogic]) do
                    if k ~= "id" then
                        mPerformData[k] = v
                    end
                end
                mData[id] = mPerformData
            else
                mPerformData["pflogic"] = id
                mData[id] = mPerformData
            end
        end
    end
    return mData
end

local function RequireTaskHead(sPath)
    local m = SafeRequire(sPath)
    local mHead = {}
    for id, mData in pairs(m) do
        mHead[mData.head] = id
    end
    return {
        link = m,
        head = mHead,
    }
end

-- taglock暂时不用此导表，需要作出顺序时使用
local function RequireTaskLock(sPath)
    local m = Require(sPath)
    local mTags = {}
    local mSeq = {}
    local lSeq = {}
    for seq, mData in pairs(m) do
        table.insert(lSeq, seq)
    end
    table.sort(lSeq)
    for idx, seq in ipairs(lSeq) do
        local mData = m[seq]
        local iTag = mData.id
        mTags[iTag] = idx
        mSeq[idx] = iTag
    end
    return {
        seq = mSeq,
        locks = mTags,
    }
end

local function RequireTaskTitle(sPath)
    local m = Require(sPath)
    local ret = {
        titles = m,
        locks = {},
    }
    for iTitle, mData in pairs(m) do
        for _, iLockTag in pairs(mData.prelocks) do
            local lTitles = ret.locks[iLockTag]
            if not lTitles then
                lTitles = {}
                ret.locks[iLockTag] = lTitles
            end
            table.insert(lTitles, iTitle)
        end
        -- for _, mLock in pairs(mData.prelocks) do
        --     local sGroup = mLock.group
        --     local iLockTag = mLock.lock
        --     local mGroupLocks = ret.locks[sGroup]
        --     if not mGroupLocks then
        --         mGroupLocks = {}
        --         ret.locks[sGroup] = mGroupLocks
        --     end
        --     local lTitles = mGroupLocks[iLockTag]
        --     if not lTitles then
        --         lTitles = {}
        --         mGroupLocks[iLockTag] = lTitles
        --     end
        --     table.insert(lTitles, iTitle)
        -- end
    end
    return ret
end

local function RequireParseTask(sPath)
    local m = Require(sPath)
    for taskid, mData in pairs(m) do
        -- 完成指令提取下一步
        local lMissionDoneStrs = mData.missiondone
        for _, sCmd in ipairs(lMissionDoneStrs) do
            local sFunc = string.match(sCmd, "^([$%a]+)")
            if sFunc == "NT" then
                local iNTid = tonumber(string.sub(sCmd, #sFunc + 1, -1))
                mData._next_task = iNTid
                break
            end
        end

        -- 领取条件
        local lAccCondiStrs = mData.acceptConditionStr
        if type(lAccCondiStrs) == "table" then
            local mCondiMap = {}
            for _, sArgs in ipairs(lAccCondiStrs) do
                local sKey,sValue = string.match(sArgs,"(.+):(.+)")
                if sKey and sValue ~= "" then
                    local iValue = tonumber(sValue)
                    if iValue then
                        mCondiMap[sKey] = iValue
                    else
                        local lValues = split_string(sValue, "|", tonumber)
                        if next(lValues) then
                            mCondiMap[sKey] = lValues
                        else
                            mCondiMap[sKey] = sValue
                        end
                    end
                end
            end
            if next(mCondiMap) then
                mData._parsed_precondi = mCondiMap
            end
        end
    end
    return m
end

local function RequireRunringAccRatio(sPath)
    local m = Require(sPath)
    for id, mRingInfo in pairs(m) do
        if mRingInfo.accept_task_ratio then
            local mRatioParsed = {}
            for _, mRatioData in ipairs(mRingInfo.accept_task_ratio) do
                mRatioParsed[mRatioData.tasktype] = mRatioData.ratio
            end
            mRingInfo.accept_task_ratio = mRatioParsed
        end
    end
    return m
end

local function RequireRunringNeedItems(sPath)
    local m = Require(sPath)
    -- local mNeedRatios = {}
    for id, mInfo in pairs(m) do
        local lGradeIn = mInfo.grade_in
        if lGradeIn then
            if #lGradeIn == 0 then
                mInfo.grade_in = nil
            elseif #lGradeIn ~= 2 then
                assert(nil, "runring <<need_items>> got 'grade_in' incorrect")
            end
        end
        local lItemSidRatioList = mInfo.itemsid_ratio
        if lItemSidRatioList then
            if next(lItemSidRatioList) then
                local mItemRatios = {}
                for _, mStruct in ipairs(lItemSidRatioList) do
                    mItemRatios[mStruct.itemsid] = mStruct.ratio
                end
                mInfo.itemsid_ratio = mItemRatios
            else
                mInfo.itemsid_ratio = nil
            end
        end
        -- local iRatio = mInfo.ratio
        -- mNeedRatios[id] = iRatio
    end
    -- return {
    --     need_ratios = mNeedRatios,
    --     detail = m,
    -- }
    return m
end

local function RequireHuodongGlobalConfig(sFilePath)
    local mData = Require(sFilePath)
    return mData[1]
end

local function DoTaskRequire(m, mTaskList, mFileList, mSpecialDeal)
    for _,sTask in pairs(mTaskList) do
        local mTask
        for _,sFile in pairs(mFileList) do
            local f = mSpecialDeal[sFile] or Require
            local sPath
            if sTask ~= "." then
                if not m[sTask] then
                    m[sTask] = {}
                end
                mTask = m[sTask]
            else
                mTask = m
            end
            sPath = string.format("task/%s/%s", sTask,sFile)
            mTask[sFile] = f(sPath)
        end
    end
end
local function RequireTaskExt()
    local m = {}

    local mTaskList = {"."}
    local mFileList = {"taglock", "taskitem", "taskpick", "choose","text", "tasktitle", "taskassist"}
    DoTaskRequire(m, mTaskList, mFileList, {tasktitle=RequireTaskTitle})

    return m
end
local function RequireTask()
    local m = {}

    local mTaskList = {
        "story","side","test",
        "shimen","ghost","yibao",
        "fuben","schoolpass","orgtask",
        "lingxi","guessgame","jyfuben", 
        "lead", "runring", "baotu", 
        "xuanshang", "zhenmo","imperialexam",
        "treasureconvoy",
    }

    -- 表在目录结构内，不改sheet名，故导出lua文件名仍一样
    local mFileList = {"task","taskevent", "taskdialog"}
    DoTaskRequire(m, mTaskList, mFileList, {taskdialog=RequireTaskDialog, task=RequireParseTask})

    for _, sTask in pairs(mTaskList) do
        local mTbl = Require(string.format("npc/task_%s_npc", sTask))
        m[sTask]["tasknpc"] = mTbl
        -- CheckRecNpcTypes(mTbl, "task." .. sTask)
    end

    local mTaskList = {"test","story","side","lead"}
    local mFileList = {"taskhead"}
    DoTaskRequire(m, mTaskList, mFileList, {taskhead=RequireTaskHead})

    DoTaskRequire(m, {"story"}, {"story_chapter", "visual_config"}, {})
    DoTaskRequire(m, {"runring"}, {"global_config", "ring_accept_ratio", "type_tasks", "sp_ring_rwd", "target_fight", "need_items",  "legend_fight", "legend_map"}, {global_config=RequireHuodongGlobalConfig, ring_accept_ratio=RequireRunringAccRatio, need_items=RequireRunringNeedItems})

    return m
end

local function RequireLiuMaiTimeConfig()
    local mConfig = Require("/huodong/liumai/time_config")[1]
    local mResult = {}
    mResult.OPEN_DAY = mConfig.open_day
    mResult.OPEN_TIME = mConfig.open_time
    local GAME_TIME = {}
    GAME_TIME.PreGameStart = mConfig.open_time[2] * 60 * 1000
    GAME_TIME.GameStart1 = mConfig.jifen_start * 60 * 1000
    GAME_TIME.GameStart2 = mConfig.taotai_start * 60 * 1000
    GAME_TIME.CloseEnterScene = mConfig.jifen_forbid_join * 60 * 1000
    GAME_TIME.GameOver2 = mConfig.jifen_gameover * 1000
    GAME_TIME.CycleReward = mConfig.cycle_reward * 1000
    GAME_TIME.MatchPoint= mConfig.jifen_match * 1000
    GAME_TIME.TTStart = mConfig.ttstart * 1000
    GAME_TIME.PointAnnounce = mConfig.jifen_chuanwen * 60 * 1000
    GAME_TIME.EndPointWar = mConfig.taotai_gameover * 1000
    mResult.GAME_TIME = GAME_TIME
    return mResult
end

local function RequireLingxiQuestion(sFilePath)
    local mData = Require(sFilePath)
    return table_key_list(mData)
end

local function RequireCampfireQuestion()
    local mResult = {}
    for _, sTName in ipairs({"fixed_choice", "custom_choice", "fill_in"}) do
        mResult[sTName] = Require("huodong/orgcampfire/" .. sTName)
    end
    return mResult
end

local function RequireBiWuTimeConfig()
    local m = Require("huodong/biwu/time_config")[1]
    local mResult = {}
    mResult.OPEN_DAY = m.open_day
    mResult.OPEN_TIME = m.open_time
    local GAME_TIME = {}
    GAME_TIME.PreGameStart = m.open_time[2] * 60 * 1000
    GAME_TIME.PushMakeTeamUI = m.push_maketeamui * 60 * 1000
    GAME_TIME.GameStart = m.game_start * 60 * 1000
    GAME_TIME.GameOver1 = m.game_over1 * 60 * 1000
    GAME_TIME.GameOver2 = m.game_over2 * 60 * 1000
    GAME_TIME.StopMatchBattle = m.stop_match_battle * 60 * 1000
    GAME_TIME.CycleReward = m.cycle_reward * 1000
    GAME_TIME.MatchBattle = m.cycle_match_battle * 1000
    GAME_TIME.TrueStartFight = m.true_start_fight * 1000
    GAME_TIME.MakeTeam = m.cycle_maketeam * 1000
    GAME_TIME.SetOrgAnnounce = m.set_org_announce * 60 * 1000
    mResult.GAME_TIME = GAME_TIME
    return mResult
end

local function RequireMoneyMonsterCnt(sFilePath)
    local mResult = {}
    local mData = Require(sFilePath)
    for _, mInfo in pairs(mData) do
        local monster_idx = mInfo.monster_idx
        mResult[monster_idx] = mResult[monster_idx] or {}
        mResult[monster_idx].monster_radio = mInfo.monster_radio 
        local mTmp = {}
        for _, mAmount in pairs(mInfo.ratio) do
            mTmp[mAmount.amount] = mAmount.ratio
        end
        mResult[monster_idx].num_radio = mTmp
    end
    return mResult
end

local function RequireCaiShenRewardTable(sFilePath)
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        mData.id = nil
        mResult[id] = mData
    end
    return mResult
end

local function RequireSingleWarConfig()
    local m = Require("huodong/singlewar/config")
    local mResult = {}
    for sKey, mData in pairs(m) do
        mData.reward_first = formula_string(mData.reward_first, {})
        mData.reward_five = formula_string(mData.reward_five, {})
        mResult[sKey] = mData
    end
    return mResult
end

local function RequireSingleWarRankReward()
    local m = Require("huodong/singlewar/rankreward")
    local mResult = {}
    for sKey, mData in pairs(m) do
        mData.reward = formula_string(mData.reward, {})
        mResult[sKey] = mData
    end
    return mResult
end

local function RequireCaishenRewardLimit()
    local m = Require("huodong/caishen/rewardlimit")
    local mResult = {}
    for _,mData in pairs(m) do
        mResult[mData.idx] = mData.limit
    end
    return mResult
end

local function RequireCaishenCost()
    local m = Require("huodong/caishen/cost")
    local mResult = {}
    for id,mData in pairs(m) do
        if not mResult[mData.group_key] then
            mResult[mData.group_key] = {}
            mResult[mData.group_key]["cost_list"] = {}
            mResult[mData.group_key]["cost_list"][mData.key] = mData
        else
            mResult[mData.group_key]["cost_list"][mData.key] = mData
        end
    end
    for sGroupKey,mData in pairs(mResult) do
        mResult[sGroupKey]["cost_size"] = #mData["cost_list"]
    end
    return mResult
end

local function RequireDayexpenseReward()
    local mResult = {}
    local m = Require("huodong/dayexpense/reward")
    for id,mData in pairs(m) do
        if not mResult[mData.group_key] then
            mResult[mData.group_key] = {}
        end
        local mTempData = {}
        mTempData.grid_list = {}
        for sSlot,mRewardIdxList in pairs(mData) do
            local iStart,iEnd = string.find(sSlot,"slot")
            if iStart and iEnd then
                local iSlot = tonumber(string.sub(sSlot,iEnd + 1,#sSlot))
                if iSlot then
                    mTempData.grid_list[iSlot] = mRewardIdxList
                end
            end
        end
        mTempData.expense = mData.expense
        mTempData.key = mData.key
        mResult[mData.group_key][mData.key] = mTempData
    end
    local FunComp = function(a,b)
        return a.expense < b.expense
    end
    for group_key,_ in pairs(mResult) do
        table.sort(mResult[group_key],FunComp)
        for id, mData in ipairs(mResult[group_key]) do
            mData.key = id
        end
    end
    return mResult
end

local function RequireThreeBiWuTimeConfig()
    local m = Require("huodong/threebiwu/time_config")[1]
    local mResult = {}
    mResult.OPEN_DAY = m.open_day
    mResult.OPEN_TIME = m.open_time
    local GAME_TIME = {}
    GAME_TIME.PreGameStart = m.open_time[2] * 60 * 1000
    GAME_TIME.GameStart = m.game_start * 60 * 1000
    GAME_TIME.GameOver1 = m.game_over1 * 60 * 1000
    GAME_TIME.GameOver2 = m.game_over2 * 60 * 1000
    GAME_TIME.CycleReward = m.cycle_reward * 1000
    GAME_TIME.MatchBattle = m.cycle_match_battle * 1000
    GAME_TIME.StopMatchBattle = m.stop_match_battle * 60 * 1000
    GAME_TIME.TrueStartFight = m.true_start_fight * 1000
    mResult.GAME_TIME = GAME_TIME
    return mResult
end

local function RequireActivePointReward()
    local mResult = {}
    local m = Require("huodong/activepoint/reward")
    for id, mData in pairs(m) do
        local mTempData = {}
        mTempData.grid_list = {}
        mTempData.id = mData.id
        mTempData.point = mData.point
        for sSlot, mRewardIdxList in pairs(mData) do
            local iStart, iEnd = string.find(sSlot, "slot")
            if iStart and iEnd then
                local iSlot = tonumber(string.sub(sSlot,iEnd + 1, #sSlot))
                if iSlot and #mRewardIdxList > 0 then
                    mTempData.grid_list[iSlot] = mRewardIdxList
                end
            end
        end
        mResult[mData.id] = mTempData
    end
    local FunComp = function(a,b)
        return a.point < b.point
    end
    table.sort(mResult, FunComp)
    for id, mData in ipairs(mResult) do
        mData.id = id
    end
    return mResult
end

local function RequireDrawcardReward()
    local mResult = {}
    mResult.common = {}
    mResult.uncommon = {}
    local m = Require("huodong/drawcard/reward")
    for id, mData in pairs(m) do
        if mData.uncommon == 1 then
            table.insert(mResult.uncommon, mData)
        else
            table.insert(mResult.common, mData)
        end
    end
    for index, mData in ipairs(mResult.uncommon) do
        mData.id = index
    end
    for index, mData in ipairs(mResult.common) do
        mData.id = index
    end
    return mResult
end

local function RequireJoyExpenseReward()
    local mResult = {}
    local mConfig = Require("huodong/joyexpense/config")
    for group_key, _ in pairs(mConfig) do
        local m = Require("/huodong/joyexpense/"..group_key)
        mResult[group_key] = {}
        for _, mData in pairs(m) do
            table.insert(mResult[group_key],mData)
        end
        local FunComp = function(a,b)
            return a.expense < b.expense
        end
        table.sort(mResult[group_key],FunComp)
        for id, mData in pairs(mResult[group_key]) do
            mData.id = id
        end
    end
    return mResult  
end

local function RequireFestivalGiftReward()
    local mResult = {}
    local m = Require("huodong/festivalgift/reward")
    for id, mData in pairs(m) do
        local start_month, start_day = mData.start_date:match("(%d+)%-(%d+)")
        local end_month, end_day = mData.end_date:match("(%d+)%-(%d+)")
        mData.start_date = tonumber(start_month) * 100 + tonumber(start_day)
        mData.end_date = tonumber(end_month) * 100 + tonumber(end_day)
        mResult[id] = mData
    end
    return mResult
end

local function RequireGoldCoinParty()
    local mResult = {}
    local m = Require("huodong/goldcoinparty/lottery_bonuspool")
    for _, mData in ipairs(m) do
        if not mResult[mData.level] then
            mResult[mData.level] = {}
            table.insert(mResult[mData.level],mData)
        else
            table.insert(mResult[mData.level],mData)
        end
        mData.level = nil
    end
    local FunComp = function(a, b)
        return a.min_bonus < b.min_bonus
    end
    for _, mLevel in ipairs(mResult) do
        table.sort(mLevel, FunComp)
    end
    return mResult
end
            
local function RequireMysticalboxConfig()
    local mResult = {}
    local m = Require("huodong/mysticalbox/config")
    mResult.lock_time = m[1].lock_time * 3600
    return mResult
end

local function RequireOrgWarConfig(sFilePath)
    local mKey = {
        enemy_win_announce = 1,
        friend_win_announce = 1,
        lose_serial_factor = 1,
        win_serial_factor = 1,
    }
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        for sKey, rVal in pairs(mData) do
            if mKey[sKey] then
                mResult[sKey] = formula_string(rVal, {})
            else
                mResult[sKey] = rVal
            end
        end
    end
    return mResult
end

local function RequireOrgWarTimeCtrl(sFilePath)
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        local iWeek = mData.week_day
        if not mResult[iWeek] then
            mResult[iWeek] = {}
        end
        table.insert(mResult[iWeek], mData)
    end
    return mResult
end

local function RequireReplaceHD(sFilePath)
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        local iWeek = mData.week_day
        mResult[iWeek] = mData
    end
    return mResult
end

local function RequireHFDMTimeCtrl(sFilePath)
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        local iWeek = mData.week_day
        if not mResult[iWeek] then
            mResult[iWeek] = {}
        end
        table.insert(mResult[iWeek], mData)
    end
    return mResult
end

local function RequireXingxiuFight(sFilePath)
    local mResult = {}
    for id, mData in pairs(Require(sFilePath)) do
        mResult[id] = formula_string(mData.fight_ratio, {})
    end
    return mResult
end

local function RequireForeShowShowConfig()
    local m = Require("huodong/foreshow/giftday")
    local mResult = {}
    local mTempData = {}
    for _,mData in pairs(m) do
        local iDay = mData.gift_day
        if not mTempData[iDay] then
            mTempData[iDay] = {}
        end
        mTempData[iDay][mData.id] = mData
    end
    mResult.giftday = mTempData
    
    m = Require("huodong/foreshow/activepoint")
    mResult.activepoint = m
    
    m = Require("huodong/foreshow/weekday")
    mTempData = {}
    for _, mData in pairs(m) do
        local iDay = mData.week_day
        if not mTempData[iDay] then
            mTempData[iDay] = {}
        end
        mTempData[iDay][mData.id] = mData
    end
    mResult.weekday = mTempData
    return mResult
end

local function RequireHuodongExtra(sName, mContent)
    local mHuodong = {
        ["fengyao"] = {"npcmap"},
        ["treasure"] = {"normalevent","advancevent"},
        ["devil"] = {"starlv", "npcmap", "npcname","fight"},
        ["shootcraps"] = {"basicreward","luckreward","flowertype","onlinetime","sixratio","config"},
        ["dance"] = {"condition"},
        ["orgcampfire"] = {
            global_config = RequireHuodongGlobalConfig,
            question = RequireCampfireQuestion,
            scene_effect = 1,
        },
        ["signin"] = {"fortune","signreward","signin_reward_set","signin_firstmonth_special"},
        ["mengzhu"] = {"condition", "org_count_reward", "org_rank_reward", "player_rank_reward"},
        ["biwu"] = {"condition","scene","rewardwin","rewardfail","winargs","reward_basic","reward_rank","floorargs", time_config = RequireBiWuTimeConfig},
        ["schoolpass"] = {"condition"},
        ["arena"] = {"condition",},
        ["moneytree"] = {condition=1,monster_cnt_ruyi=RequireMoneyMonsterCnt,monster_cnt_jixiang=RequireMoneyMonsterCnt},
        ["baike"] = {"condition","question","score", "currank_reward", "weekrank_reward"},
        ["charge"] = {"day_gift", "goldcoin_gift", "grade_gift", "config"},
        ["bottle"] = {"config",},
        ["liumai"] = {"condition","scene","win_redpacket","jinji_redpacket", time_config = RequireLiuMaiTimeConfig},
        ["guessgame"] = {"scene", "config","scene_effect"},
        ["lingxi"] = {
            flower_use_pos = 1,
            global_config = RequireHuodongGlobalConfig,
            choose_question = RequireLingxiQuestion,
            qte_config = 1,
        },
        ["jyfuben"] = {"condition","scene","clientconfig"},
        ["welfare"] = {"first_pay_gift", "rebate_gift", "login_gift", "second_pay_gift"},
        ["collect"] = {"collect_gift", "collect_config", "collect_item"},
        ["caishen"] = {"config", cost = RequireCaishenCost, rewardlimit = RequireCaishenRewardLimit},
        ["orgwar"] = {"scene", "signin", time_ctrl=RequireOrgWarTimeCtrl, config=RequireOrgWarConfig, replace_hd=RequireReplaceHD},
        ["hfdm"] = {"scene", "questions", "skill", "answer_wrong_bianshen", global_config = RequireHuodongGlobalConfig, time_ctrl = RequireHFDMTimeCtrl, },
        ["trial"] = {"config", "match_rule"},
        ["grow"] = {"config","taskend"},
        ["returngoldcoin"] = {"config", "formula_config", "reward_config"},
        ["kaifudianli"] = {"config","orgcnt","orglevel","playerscore","playergrade"},
        ["sevenlogin"] = {"config","reward"},
        ["everydaycharge"] = {"reward"},
        ["xingxiu"] = {"config", fight_config = RequireXingxiuFight,},
        ["onlinegift"] = {"condition","online_gift"},
        ["superrebate"] = {"config","lottery","rebate","pay"},
        ["totalcharge"] = {"config","new_reward","old_reward","third_reward"},
        ["dayexpense"] = {"config",reward = RequireDayexpenseReward},
        ["fightgiftbag"] = {"config","reward"},
        ["fuyuanbox"] = {"config"},
        ["threebiwu"] = {"config","condition","scene","match", time_config = RequireThreeBiWuTimeConfig},
        ["qifu"] = {"config","degree_reward","lottery_reward","baoji_ratio"},
        ["jubaopen"] = {"config","rank_reward","score_reward"},
        ["activepoint"] = {"config",reward = RequireActivePointReward},
        ["drawcard"] = {"config",reward = RequireDrawcardReward,"times_cost"},
        ["nianshou"] = {"npcmap","config"},
        ["continuouscharge"] = {"config", "new_reward", "old_reward", "new_total_reward", "old_total_reward"},
        ["continuousexpense"] = {"config", "new_reward", "old_reward", "new_total_reward", "old_total_reward"},
        ["everydayrank"] = {"config"},
        ["festivalgift"] = {reward = RequireFestivalGiftReward},
        ["goldcoinparty"] = {"config","degree_reward","lottery_reward","lottery_level",lottery_bonuspool = RequireGoldCoinParty, },
        ["mysticalbox"] = {config = RequireMysticalboxConfig,"reward"},
        ["luanshimoying"] = {"config", "boss_config", "score_config"},
        ["jiebai"] = {"config","invite_cnt","scene","vote","minghao"},
        ["joyexpense"] = {"config",reward = RequireJoyExpenseReward},
        ["singlewar"] = {"scene", "grade2scene", "seriwin2ratio", rankreward=RequireSingleWarRankReward, config=RequireSingleWarConfig,},
        ["imperialexam"] = {"time_ctrl","config","top3_reward","firststage_question","secondstage_question"},
        ["iteminvest"] = {"config", "new_reward", "old_reward"},
        ["treasureconvoy"] = {"config", "monster", "convoy_title", "scene"},
        ["foreshow"] = {show_config = RequireForeShowShowConfig,},
        ["discountsale"] = {"discount_goods"},
        ["zeroyuan"] = {"config", "activity"},
        ["retrieveexp"] = {"config", "retrieve"},
		["worldcup"] = {"config", "country", "phase_cost", "suc_times_title", "fail_times_title"},
        ["zongzigame"] = {"config"},
        ["duanwuqifu"] = {"config", "reward_step"},
    }
    if not mHuodong[sName] then
        return nil
    end

    for k, v in pairs(mHuodong[sName]) do
        local sFile, fParse
        if type(k) == "number" then
            sFile = v
        else
            sFile = k
            fParse = v
        end
        local mData
        local sFilePath = string.format("huodong/%s/%s", sName, sFile)
        if sName == "signin" and sFile == "signin_reward_set" then
            sFilePath = string.format("reward/%s", sFile)
        end
        if sName == "signin" and sFile == "signin_firstmonth_special" then
            sFilePath = string.format("reward/%s", sFile)
        end
        if type(fParse) == "function" then
            mData = fParse(sFilePath)
        else
            mData = Require(sFilePath)
        end
        mContent[sFile] = mData
    end
end

local function RequireHuodong()
    local mHuodong = {
        "fengyao", "trapmine", "treasure", 
        "devil", "arena", "shootcraps", 
        "dance", "orgcampfire", "signin", 
        "mengzhu", "biwu", "schoolpass", 
        "orgtask", "lingxi", "moneytree", 
        "baike", "charge", "caishen",
        "liumai", "bottle", "guessgame", 
        "jyfuben", "welfare", "collect", 
        "orgwar", "hfdm", "trial", 
        "grow", "returngoldcoin", "kaifudianli", 
        "sevenlogin", "everydaycharge", "xingxiu", 
        "onlinegift","superrebate","totalcharge",
        "fightgiftbag", "dayexpense", "threebiwu", 
        "fuyuanbox","qifu", "jubaopen",
        "activepoint","drawcard","nianshou",
        "continuouscharge", "continuousexpense", "everydayrank",
        "festivalgift","goldcoinparty","mysticalbox",
        "luanshimoying","jiebai","joyexpense","singlewar",
        "imperialexam", "iteminvest","treasureconvoy",
        "foreshow","discountsale", "zeroyuan",
		"retrieveexp", "worldcup", "zongzigame","duanwuqifu",
    }
    local mFile = {"npc","event","text","choose"}
    local m = {}
    for _,sName in pairs(mHuodong) do
        m[sName] = {}
        for _,sFile in pairs(mFile) do
            local mTbl = Require(string.format("huodong/%s/%s",sName,sFile))
            if mTbl then
                m[sName][sFile] = mTbl
                -- if sFile == "npc" then
                --     CheckRecNpcTypes(mTbl, "huodong." .. sName)
                -- end
            end
        end
        RequireHuodongExtra(sName, m[sName])
    end

    return m
end

local function RequireFileFight(sFile)
    local m = {}
    return m
end

local function _ParseNewKey(mData, sNewKey)
    local m = {}
    for _, mInfo in pairs(mData) do
        local xNewkey = mInfo[sNewKey]
        if xNewkey then
            local mNode = m[xNewkey]
            if not mNode then
                mNode = {}
                m[xNewkey] = mNode
            end
            table.insert(mNode, mInfo)
        end
    end
    return m
end

local function RequireFight()
    local mFile = {
        arena = 1,
        devil = {"group"},
        fengyao = {"group"},
        nianshou = {"group"},
        fuben = {"speek"},
        ghost = {"speek"},
        guessgame = {"speek"},
        mengzhu = 1,
        moneytree = {"speek"},
        orgtask = {"custom_speek"},
        schoolpass = {"custom_speek"},
        shimen = {"speek", "mirror_school"},
        side = {"speek"},
        lead = {"speek"},
        story = {"speek"},
        test = {"speek"},
        trapmine = 1,
        yibao = {"speek"},
        jyfuben = {"custom_speek"},
        baotu = 1,
        runring = {"speek"},
        xingxiu = 1,
        xuanshang = 1,
        luanshimoying = {"speek", "group"},
        zhenmo = 1,
        treasureconvoy = 1,
    }
    local mFight = {
        monster = 1,
        tollgate = 1,
    }
    local mExParser = {
        speek = function(mData) return _ParseNewKey(mData, "speek_id") end,
        custom_speek = function(mData) return _ParseNewKey(mData, "custom_speek_id") end,
    }
    local m = {}
    for sName, lEx in pairs(mFile) do
        m[sName] = {}
        for sFight, func in pairs(mFight) do
            local mData = Require(string.format("fight/%s_%s",sName,sFight))
            if mData and type(func) == "function" then
                mData = func(mData)
            end
            m[sName][sFight] = mData
        end
        if type(lEx) == "table" then
            for _, sExTbl in ipairs(lEx) do
                local mData = Require(string.format("fight/%s_%s", sName, sExTbl))
                if mExParser[sExTbl] then
                    m[sName][sExTbl] = mExParser[sExTbl](mData)
                else
                    m[sName][sExTbl] = mData
                end
                
            end
        end
    end
    return m
end

local function RequireRewardLimit(sPath)
    local mRet = {}
    local mData = Require(sPath)
    for _, mInfo in pairs(mData) do
        mRet[mInfo.idx] = mInfo.limit
    end
    return mRet
end

local function RequireFileReward(sName)
    local mFunc = {
        itemreward = RequireItemReward,
        summonreward = RequireSummonReward,
        rewardlimit = RequireRewardLimit,
    }
    local mReward = {"reward", "itemreward"}
    local mExReward = {
        mengzhu = {"rewardlimit"},
        fengyao = {"rewardlimit"},
        devil = {"rewardlimit"},
        fumo = {"rewardlimit"},
        trapmine = {"rewardlimit"},
        treasure = {"rewardlimit"},
        shootcraps = {"rewardlimit"},
        everydaytask = {"rewardlimit"},
        shimen = {"rewardlimit"},
        ghost = {"rewardlimit"},
        yibao = {"rewardlimit"},
        qte = {"rewardlimit"},
        schoolpass = {"rewardlimit"},
        orgcampfire = {"rewardlimit"},
        moneytree = {"rewardlimit"},
        charge = {"rewardlimit"},
        bottle = {"rewardlimit"},
        lingxi = {"rewardlimit"},
        hfdm = {"rewardlimit"},
        orgwar = {"rewardlimit"},
        guessgame = {"rewardlimit"},
        baike = {"rewardlimit"},
        collect = {"rewardlimit"},
        runring = {"rewardlimit"},
        xingxiu = {"rewardlimit"},
        onlinegift = {"rewardlimit"},
        xuanshang = {"rewardlimit"},
        singlewar = {"rewardlimit"},
		zongzigame = {"rewardlimit"},
        duanwuqifu = {"rewardlimit"},
    }
    local function _DoParse(sName, sReward)
        local sFile = string.format("%s_%s",sName,sReward)
        local sPath = string.format("reward/%s",sFile)
        local fParse = mFunc[sReward] or Require
        return fParse(sPath)
    end
    local m = {}
    for _, sReward in pairs(mReward) do
        local mData = _DoParse(sName, sReward)
        m[sReward] = mData
        if sReward == "reward" then
            for idx, mRow in pairs(mData) do
                if not mRow.summon then
                    break
                elseif #mRow.summon > 0 then
                    m["summonreward"] = _DoParse(sName, "summonreward")
                    break
                end
            end
        end
    end
    for _, sReward in pairs(mExReward[sName] or {}) do
        m[sReward] = _DoParse(sName, sReward)
    end
    return m
end

local function RequireReward()
    local mDir = {
        "story", "side", "shimen", 
        "test", "lead", "fengyao", 
        "trapmine", "ghost", "treasure", 
        "devil", "mail", "yibao", 
        "qte", "chuxiao1", "orgcampfire", 
        "signin", "mengzhu", "gradegift", 
        "fumo", "schoolpass", "shootcraps", 
        "biwu", "preopen", "newbie","jingsan", 
        "openbox", "orgtask", "everydaytask", 
        "moneytree", "baike", "charge", 
        "liumai", "bottle", "lingxi", 
        "guessgame", "jyfuben", "welfare", 
        "collect", "orgwar", "dance", 
        "trial", "hfdm", "grow", 
        "returngoldcoin", "kaifudianli", "baotu", 
        "runring","sevenlogin", "everydaycharge", 
        "xingxiu", "onlinegift", "totalcharge", 
        "dayexpense", "xuanshang", "fightgiftbag", 
        "threebiwu", "fuyuanbox", "fumo_hard", 
        "jingsan_hard", "qifu", "jubaopen",
        "activepoint","drawcard","nianshou",
        "continuouscharge", "continuousexpense",
        "festivalgift","goldcoinparty","mysticalbox",
        "mentoring", "luanshimoying","joyexpense",
        "zhenmo","singlewar","imperialexam",
        "treasureconvoy", "zeroyuan","zongzigame",
		"worldcup", "duanwuqifu",
    }
    local m = {}
    for _,sName in ipairs(mDir) do
        m[sName] = RequireFileReward(sName)
    end
    return m
end

local function RequireUpGrade()
    return Require("system/role/upgrade")
end

local function RequireSkill()
    local mRet = {}
    local mType = {"active_school","passive_school", "xiulian_passive","se","fuzhuan","marry","artifact","fabao"}
    local mFuZhuanItem = {}
    for _,sType in pairs(mType) do
        local sPath = string.format("skill/%s",sType)
        local mSkillData = Require(sPath)
        for iSk,mData in pairs(mSkillData) do
            mRet[iSk] = mData
            if sType == "fuzhuan" then 
                mFuZhuanItem[mData.itemsid] = iSk
            end
        end
    end
    mRet.text = Require("skill/text")
    mRet.fuzhuanitem = mFuZhuanItem
    mRet.config = Require("skill/config")
    mRet.skill_confilict = Require("skill/skill_confilict")
    mRet.skill_range = Require("skill/skill_range")
    return mRet
end

local function RequireEquipAttach()
    local m = SafeRequire("system/dazao/attachattr")
    local ret = {}
    local mAttr = {}
    for _,mData in pairs(m) do
        local id = mData["attachId"]
        if not mAttr[id] then
            mAttr[id] = {}
        end
        table.insert(mAttr[id],mData)
    end
    for id,mData in pairs(mAttr) do
        ret[id] = {
            id = id,
            attr = mData
        }
    end
    return ret
end

local function RequireEquipSe()
    local m = SafeRequire("system/dazao/equipse")
    local ret = {}
    for _,mData in pairs(m) do
        local iGrade = mData["grade"]
        if not ret[iGrade] then
            ret[iGrade] = {}
        end
        local iPos = mData["pos"]
        if not ret[iGrade][iPos] then
            ret[iGrade][iPos] = {}
        end
        table.insert(ret[iGrade][iPos],{se=mData["se"],ratio=mData["ratio"],name=mData["name"]})
    end
    return ret
end

local function RequireEquipSK()
    local mResult = {}
    local mData = Require("system/dazao/equipsk")
    for _, mInfo in pairs(mData) do
        if not mResult[mInfo.grade] then
            mResult[mInfo.grade] = {}
        end
        table.insert(mResult[mInfo.grade], mInfo)
    end
    return mResult
end

local function RequireStrength()
    local m = Require("system/dazao/strength")
    local ret = {}
    for _,mData in pairs(m) do
        local iLevel = mData["strengthLevel"]
        local iPos = mData["pos"]
        if not ret[iLevel] then
            ret[iLevel] = {}
        end
        ret[iLevel][iPos] = {level=iLevel,pos=iPos,strength_effect=mData["strength_effect"]}
    end
    return ret
end

local function RequireStrengthMaster()
    local m = Require("system/dazao/strength_master")
    local ret = {}
    for _,mData in pairs(m) do
        local iSchool = mData["school"]
        local iLevel = mData["master_level"]
        local iAll_Strength_Level = mData["all_strength_level"]
        if not ret[iSchool] then
            ret[iSchool] = {}
        end
        ret[iSchool][iAll_Strength_Level] = {school=iSchool,level=iLevel,all_strength_level=iAll_Strength_Level,strength_effect=mData["strength_effect"]}
    end
    return ret
end

local function RequireStrengthMaterial()
    local m = Require("system/dazao/strength_material")
    local ret = {}
    for _,mData in pairs(m) do
        local iLevel = mData["level"]
        local iPos = mData["pos"]
        if not ret[iLevel] then
            ret[iLevel] = {}
        end
        ret[iLevel][iPos] = {level=iLevel,pos=iPos,sid=mData["sid"],amount=mData["amount"]}
    end
    return ret
end

local function RequireEquipBreak()
    local m = Require("system/dazao/equip_break")
    local ret = {}
    for _,mData in pairs(m) do
        local iLevel = mData["break_lv"]
        local iPos = mData["pos"]
        if not ret[iLevel] then
            ret[iLevel] = {}
        end
        ret[iLevel][iPos] = mData
    end
    return ret
end

local function RequireFunHunExtra()
    local m = Require("system/dazao/fuhunextra")
    local ret = {}
    for _, mData in pairs(m) do
        local iPos = mData["pos"]
        if not ret[iPos] then
            ret[iPos] = {}
        end
        table.insert(ret[iPos], mData)
    end
    return ret 
end

local function RequireWashEquip()
    local m = Require("system/dazao/wash_equip")
    local ret = {}
    for _,mData in pairs(m) do
        local iLevel = mData["level"]
        local iPos = mData["pos"]
        if not ret[iLevel] then
            ret[iLevel] = {}
        end
        ret[iLevel][iPos] = mData
    end
    return ret
end

local function RequireText(sUrl)
    local mData = {}
    if sUrl then
        mData["text"] = Require(string.format("%s/%s",sUrl,"text"))
        mData["choose"] = Require(string.format("%s/%s",sUrl,"choose"))
    else
        mData["text"] = Require("text")
        mData["choose"] = Require("choose")
    end
    return mData
end

local function RequireEquipFenjie()
    local m = Require("system/dazao/equip_fenjie")
    local ret = {}
    for _,mData in pairs(m) do
        local iLevel = mData["level"]
        local iPos = mData["pos"]
        local iQuality = mData["quality"]
        if not ret[iLevel] then
            ret[iLevel] = {}
        end
        if not ret[iLevel][iPos] then
            ret[iLevel][iPos] = {}
        end
        ret[iLevel][iPos][iQuality] = mData
    end
    return ret
end

local function RequireFenjieKu()
    local m = Require("system/dazao/fenjie_ku")
    local ret = {}
    for _,mData in pairs(m) do
        local id = mData["fenjie_id"]
        if not ret[id] then
            ret[id] = {}
        end
        table.insert(ret[id],{sid=mData["sid"],minAmount=mData["minAmount"],maxAmount=mData["maxAmount"]})
    end
    return ret
end

local function RequirePartner()
    local ret = {}
    ret["info"] = Require("system/partner/info")
    ret["type"] = Require("system/partner/type")
    ret["race"] = Require("system/partner/race")
    ret["school"] = Require("system/partner/school")
    ret["prop"] = Require("system/partner/prop")
    ret["quality"] = Require("system/partner/quality")
    ret["upper"] = Require("system/partner/upper")
    ret["skill"] = Require("skill/partner")
    ret["suilt"] = Require("system/partner/suilt")
    local m = Require("system/partner/skillunlock")
    local mIndex = {}
    for id, mData in pairs(m) do
        local iPartner = mData.partner
        if not mIndex[iPartner] then
            mIndex[iPartner] ={}
        end
        mIndex[iPartner][mData.class] = id
    end
    if next(mIndex) then
        m.index = mIndex
    end
    ret["skillunlock"] = m
    m = Require("system/partner/skillupgrade")
    mIndex = {}
    for id, mData in pairs(m) do
        local iSk = mData.skill_id
        if not mIndex[iSk] then
            mIndex[iSk] = {}
        end
        mIndex[iSk][mData.level] = id
    end
    if next(mIndex) then
        m.index = mIndex
    end
    ret["skillupgrade"] = m
    m = Require("system/partner/qualitycost")
    mIndex = {}
    for id, mData in pairs(m) do
        local iPartner = mData.partner
        if not mIndex[iPartner] then
            mIndex[iPartner] ={}
        end
        mIndex[iPartner][mData.quality] = id
    end
    if next(mIndex) then
        m.index = mIndex
    end
    ret["qualitycost"] = m
    m = Require("system/partner/point")
    mIndex = {}
    for id, mData in pairs(m) do
        local iPartner = mData.partner
        if not mIndex[iPartner] then
            mIndex[iPartner] ={}
        end
        mIndex[iPartner][mData.quality] = id
    end
    if next(mIndex) then
        m.index = mIndex
    end
    ret["point"] = m
    m = Require("system/partner/upperlimit")
    mIndex = {}
    for id, mData in pairs(m) do
        local iPartner = mData.partner
        if not mIndex[iPartner] then
            mIndex[iPartner] ={}
        end
        mIndex[iPartner][mData.upper] = id
    end
    if next(mIndex) then
        for partnerid, ids in pairs(mIndex) do
            local mSumAttr = {}
            for iUpper, id in ipairs(ids) do
                local mData = m[id]
                local mAttr = {}
                for _, mAddAttr in pairs(mData.add_attr) do
                    local sName = mAddAttr.name
                    mAttr[sName] = mAddAttr.val + (mSumAttr[sName] or 0)
                    mSumAttr[sName] = mAttr[sName]
                end
                mData.add_attr = mAttr
            end
        end
        m.index = mIndex
    end
    ret["upperlimit"] = m
    ret["text"] = Require("system/partner/text")
    ret["exp"] = Require("system/partner/exp")
    
    local mProtectSkill = {}
    for iPartner, mSkillList in pairs(Require("system/partner/protect_skill")) do
        local mData = {}
        for _, mSkill in ipairs(mSkillList.protect_skill_list) do
            mData[mSkill.school] = mSkill.skill_id
        end
        mProtectSkill[iPartner] = mData
    end
    ret["protect_skill"] = mProtectSkill

    local mPartnerEquip = {}
    local mPartner2EquipPos = {}
    for _, mEquipInfo in pairs(Require("system/partner/partnerequip")) do
        mPartnerEquip[mEquipInfo.equip_sid] = mEquipInfo

        local mEquipPos = mPartner2EquipPos[mEquipInfo.partner_id] or {}
        mEquipPos[mEquipInfo.equip_sid] = 1
        mPartner2EquipPos[mEquipInfo.partner_id] = mEquipPos
    end
    ret["partner_equip"] = mPartnerEquip
    ret["partner2equipsid"] = mPartner2EquipPos
    ret["partner_equip_upgrade_cost"] = Require("system/partner/upgrade_cost")
    ret["partner_equip_strength_cost"] = Require("system/partner/strength_cost")
    return ret
end

local function RequireGhostName()
    local sFile = "task/ghost/ghostname"
    local m = Require(sFile)
    local ret = {}
    for i=1,3 do
        ret[i] = {}
    end
    for _,mData in pairs(m) do
        local name1 = mData["name1"]
        local name2 = mData["name2"]
        local name3 = mData["name3"]
        for i=1,3 do
            local sName = string.format("name%d",i)
            local sValue = mData[sName]
            table.insert(ret[i],sValue)
        end
    end
    return ret
end

local function RequireOrgShop(mData)
    local mRet = {}
    for _,oItem in pairs(mData) do
        local m = mRet[oItem.level] or {}
        local min = m["total"] or 0
        local max = min + oItem.weight
        m["total"] = max
        if not m["data"] then
            m["data"] = {}
        end
        table.insert(m["data"], {["min"]=min, ["max"]=max, ["ibuy"]=oItem.id})
        mRet[oItem.level] = m
    end
    return mRet
end

local function RequireOrgAchieve(mData)
    local mRet = {}
    for iAch, m in pairs(mData) do
        local iType = m["type"]
        local lAch = mRet[iType] or {}
        table.insert(lAch, iAch)
        mRet[iType] = lAch
    end
    return mRet
end

local function RequireOrgBuildLevel(mData)
    local mRet = {}
    for _, m in pairs(mData) do
        local iBid, iLv = m["build_id"], m["level"]
        local mBuild = mRet[iBid] or {}
        mBuild[iLv] = m
        mRet[iBid] = mBuild
    end
    return mRet
end

local function RequireOrg()
    local ret  = {}
    local mFileList = { 
        "honorid","others","positionid",
        "positionauthority","positionlimit", 
        "text", "choose", "buildlevel", 
        "quick", "shop", "achieve", 
        "scene", "scene_effect", 
        "orgactivity", "shopbox", "shopboxnum"}
    for _,sFile in pairs(mFileList) do
        ret[sFile] = Require(string.format("system/org/%s",sFile))
    end
    ret["orgshop"] = RequireOrgShop(ret.shop)
    ret["achtype"] = RequireOrgAchieve(ret.achieve)
    ret["buildlevel"] = RequireOrgBuildLevel(ret.buildlevel)
    return ret
end

local function RequireTitle()
    local ret  = {}
    local mFileList = {"title", "text", "choose"}
    for _,sFile in pairs(mFileList) do
        ret[sFile] = Require(string.format("system/title/%s",sFile))
    end
    return ret
end

local function RequireTouxian()
    local ret  = {}
    local mFileList = {"text", "choose","touxian"}
    for _,sFile in pairs(mFileList) do
        ret[sFile] = Require(string.format("system/touxian/%s",sFile))
    end
    local mTouxian = {}
    for iTouXian,mData in pairs(ret["touxian"]) do
        local mApply = {}
        for _,mInfo in pairs(mData["apply"]) do 
            mApply[mInfo.attr] = mInfo.value
        end
        mData.apply = mApply
    end
    return ret
end

local function RequireShimenRatio()
    -- { iSchool = {
    --         iRatioLv = {
    --             iTaskId = iRatio, ...
    --         }, ...
    --     }, ...
    -- }
    local ret = {}
    for _, mData in pairs(Require("task/shimen/shimentaskratio")) do
        local iTaskId = mData["task"]
        local iSchool = mData["school"]
        local mSchool = ret[iSchool]
        if not mSchool then
            mSchool = {}
            ret[iSchool] = mSchool
        end
        for sKey, xValue in pairs(mData) do
            local iRatioLv = tonumber(string.match(sKey, "ratio_(%d+)"))
            if iRatioLv then
                local iRatio = xValue
                if 0 < xValue then
                    local mRatio = mSchool[iRatioLv]
                    if not mRatio then
                        mRatio = {}
                        mSchool[iRatioLv] = mRatio
                    end
                    mRatio[iTaskId] = iRatio
                end
            end
        end
    end

    -- check
    -- FIXME 正式导表需要此assert逻辑检测
    -- for iSchool, mSchool in pairs(ret) do
    --     for iRatioLv, mRatio in pairs(mSchool) do
    --         local iRatioSum = 0
    --         for iTaskId, iRatio in pairs(mRatio) do
    --             iRatioSum = iRatioSum + iRatio
    --         end
    --         assert(iRatioSum == 100, string.format("shimentaskratio门派%d的ratio_%d概率和不为100", iSchool, iRatioLv))
    --     end
    -- end

    return ret
end

local function RequireQueryRoleType(mRoletype)
    local mRoleTypeQuery = {}
    for _, mInfo in pairs(mRoletype) do
        local mSclInfo = mRoleTypeQuery[mInfo.school]
        if not mSclInfo then
            mSclInfo = {}
            mRoleTypeQuery[mInfo.school] = mSclInfo
        end
        mSclInfo[mInfo.sex] = mInfo.roletype
    end
    return mRoleTypeQuery
end

local function RequireRank(sPath)
    local mData = Require("system/rank/rankinfo")
    local mRet = {}
    for idx, v in pairs(mData) do
        mRet[idx] = {["idx"] = v.id, ["name"] = v.file,["refreshtype"]=v.refreshtype,["refreshhour"]=v.refreshhour, ["alias"] = v.name,}
    end
    return mRet
end

local function RequireFormationAttr()
    local mAttrInfo = Require("system/formation/attrinfo")
    local mResult = {}
    for idx, mInfo in pairs(mAttrInfo) do
        local iFmt = mInfo.fmt_id
        if not mResult[iFmt] then
            mResult[iFmt] = {}
        end
        local mData = {}
        mData.base_attr = mInfo.base_attr
        mData.ext_attr = mInfo.ext_attr
        local iPos = mInfo.pos
        mResult[iFmt][iPos] = mData
    end
    return mResult
end

local function RequireFmtID2BookSid()
    local mItemInfo = Require("system/formation/iteminfo")
    local mResult = {}
    for iBookSid,mInfo in pairs(mItemInfo) do
        mResult[mInfo.fmt_id] = iBookSid
    end
    return mResult
end

local function RequireFormation()
    local mResult = {}
    local mBaseInfo = Require("system/formation/baseinfo")
    mResult.base_info = mBaseInfo
    local mAttrInfo = RequireFormationAttr()
    mResult.attr_info = mAttrInfo
    local mItemInfo = Require("system/formation/iteminfo")
    mResult.item_info = mItemInfo
    local mUseInfo = Require("system/formation/useinfo")
    mResult.use_limit = mUseInfo
    local mTextInfo = Require("system/formation/text")
    mResult.text = mTextInfo
    local mFmtID2BookSid = RequireFmtID2BookSid()
    mResult.fmt_booksid = mFmtID2BookSid
    return mResult
end

local function RequireStall()
    local mResult = {}
    mResult.text = Require("economic/stall/text")
    local mCatalog = {}
    mResult.catalog = mCatalog
    mResult.stall_config = Require("economic/stall/stall_config")

    local mItemInfo = Require("economic/stall/iteminfo")
    mResult.iteminfo = mItemInfo
    for _, mInfo in pairs(mItemInfo) do
        mInfo.max_price = math.floor(mInfo.max_price * mInfo.base_price/100)
        mInfo.min_price = math.floor(mInfo.min_price * mInfo.base_price/100)
        local iCat, iSid = mInfo.cat_id, mInfo.item_id
        if not mCatalog[iCat] then
            mCatalog[iCat] = {}
        end
        table.insert(mCatalog[iCat], iSid)
    end
    return mResult
end

local function RequireFastBuyItem()
    local m = Require("economic/fastbuy/fastbuyitem")
    local mResult = {}
    for _, mData in ipairs(m) do
        for sid = mData.start_sid, mData.end_sid do
            mResult[sid] = mData.storetype
        end
    end
    return mResult
end

local function RequireShowId()
    local mResult = {}
    local mExcellent = Require("system/showid/excellent")
    mResult.excellent = mExcellent
    return mResult
end

local function RequireJJC()
    local mResult = {}
    mResult.robot_base = Require("system/jjc/robot_base")
    mResult.robot_attr = Require("system/jjc/robot_attr")
    mResult.graderatio = Require("system/jjc/graderatio")
    mResult.school_partner = Require("system/jjc/school_partner")
    mResult.robot_partner = Require("system/jjc/robot_partner")
    mResult.partner_attr = Require("system/jjc/partner_attr")
    mResult.summon_attr = Require("system/jjc/summon_attr")
    mResult.target_rank = Require("system/jjc/target_rank")
    mResult.fight_reward = Require("system/jjc/fight_reward")
    mResult.day_reward = Require("system/jjc/day_reward")
    mResult.month_reward = Require("system/jjc/month_reward")
    mResult.day_reward_ratio = Require("system/jjc/day_reward_ratio")
    mResult.month_reward_ratio = Require("system/jjc/month_reward_ratio")
    mResult.challenge_group = Require("system/jjc/challenge_group")
    mResult.challenge_power = Require("system/jjc/challenge_power")
    mResult.challenge_reward_beatall = Require("system/jjc/challenge_reward_beatall")
    
    mResult.buy_jjctimes = Require("system/jjc/buy_jjctimes")
    mResult.text = Require("system/jjc/text")
    mResult.choose = Require("system/jjc/choose")
    mResult.jjc_global = Require("system/jjc/jjc_global")
    mResult.rewardlimit = RequireRewardLimit("system/jjc/rewardlimit")
    local lChlgRNormal = Require("system/jjc/challenge_reward_normal")
    local mChlgRNormal = {}
    for _, info in ipairs(lChlgRNormal) do
        local mGroup = mChlgRNormal[info.group]
        if not mGroup then
            mGroup = {}
            mChlgRNormal[info.group] = mGroup
        end
        mGroup[info.beatcnt] = info
    end
    mResult.challenge_reward_normal = mChlgRNormal
    local mChlRLimit = {}
    local lChlRLimit = RequireRewardLimit("system/jjc/challenge_rewardlimit")
    mChlRLimit.rewardlimit = lChlRLimit
    mResult.challenge_rewardlimit = mChlRLimit
    return mResult
end

local function RequireGuild()
    local mResult = {}
    mResult.iteminfo = Require("economic/guild/iteminfo")
    mResult.text = Require("economic/guild/text")
    mResult.guild_config = Require("economic/guild/guild_config")
    local mSlv2Item = {}
    local mSid2Good = {}
    for iSid, mInfo in pairs(mResult.iteminfo) do
        mInfo.max_price = math.floor(mInfo.base_price * mInfo.max_price / 100)
        mInfo.min_price = math.floor(mInfo.base_price * mInfo.min_price / 100)
        local slv = mInfo.slv
        if not mSlv2Item[slv] then
            mSlv2Item[slv] = {}
        end
        mSid2Good[mInfo.item_sid] = iSid
        table.insert(mSlv2Item[slv], iSid)
    end
    mResult.slv2item = mSlv2Item
    mResult.sid2good = mSid2Good
    return mResult
end

local function RequireFuben(sFubenName)
    local mResult = {}
    local lFile = {"event", "npc", "scene", "text", "choose"}
    for _, sFile in ipairs(lFile) do
        local sPath = string.format("fuben/%s/%s", sFubenName, sFile)
        local t = Require(sPath)
        mResult[sFile] = t
    end
    return mResult
end

local function RequireRandRoleName()
    local mData = Require("system/role/randomname")
    local iSize = 0
    local lFirstNames  = {}
    local lMaleNames = {}
    local lFemaleNames = {}
    local sName
    for id, mNameInfo in pairs(mData) do
        sName = mNameInfo.firstName
        if sName ~= "" then
            table.insert(lFirstNames, sName)
        end
        sName = mNameInfo.maleName
        if sName ~= "" then
            table.insert(lMaleNames, sName)
        end
        sName = mNameInfo.femaleName
        if sName ~= "" then
            table.insert(lFemaleNames, sName)
        end
    end
    return {
        first_name = lFirstNames,
        male_name = lMaleNames,
        female_name = lFemaleNames,
    }
end

local function RequireRandNpcName()
    local mData = Require("system/role/randomnpcname")
    local iSize = 0
    local lFirstNames  = {}
    local lMiddleNames = {}
    local lLastNames   = {}
    local sName
    for id, mNameInfo in pairs(mData) do
        iSize = iSize + 1
        sName = mNameInfo.first_name
        if sName ~= "" then
            table.insert(lFirstNames, sName)
        end
        sName = mNameInfo.middle_name
        if sName ~= "" then
            table.insert(lMiddleNames, sName)
        end
        sName = mNameInfo.last_name
        if sName ~= "" then
            table.insert(lLastNames, sName)
        end
    end
    return {
        size = iSize,
        first_name = lFirstNames,
        middle_name = lMiddleNames,
        last_name = lLastNames,
    }
end

local function RequireFubenConfig()
    local mData = Require("fuben/config")
    local mRefresh = {}
    local lFubenName = {}
    for iFuben, mFuben in pairs(mData) do
        if not mRefresh[mFuben.refresh_type] then
            mRefresh[mFuben.refresh_type] = {}
        end
        table.insert(mRefresh[mFuben.refresh_type], iFuben)
        table.insert(lFubenName, mFuben.fuben_name)
    end
    local mResult = {}
    mResult.fuben_config = mData
    mResult.fuben_refresh = mRefresh
    mResult.text = Require("fuben/text")
    mResult.taskgroup = Require("fuben/taskgroup")

    for _, sFubenName in ipairs(lFubenName) do
        mResult[sFubenName] = RequireFuben(sFubenName)
    end

    return mResult
end

local function RequireZhenmoConfig()
    local mData = Require("system/zhenmo/layer_config")
    local mResult = {}
    mResult.layer_config = mData
    mResult.text = Require("system/zhenmo/text")
    mResult.scene = Require("system/zhenmo/scene")
    return mResult
end


local function RequireStoryAnimeQte()
    local mData = Require("qte/story_anime_qte")
    local mResult = {}
    for _, mInfo in pairs(mData) do
        local mAnime = mResult[mInfo.animeid]
        if not mAnime then
            mAnime = {}
            mResult[mInfo.animeid] = mAnime
        end
        mAnime[mInfo.qteid] = mInfo
    end
    return mResult
end

local function RequireRide()
    local ret  = {}
    local mFileList = {"buytime","other","text","choose", "upgrade", "rideinfo"}
    for _,sFile in pairs(mFileList) do
        ret[sFile] = Require(string.format("system/ride/%s",sFile))
    end

    local lKeyAttr = {"shushan", "jinshan", "xingxiu", "yaochi", "qingshan", "yaoshen"}
    local mPreData = {}
    local mUpgrade = ret["upgrade"]
    for iLv = 0, 200 do
        local mData = mUpgrade[iLv]
        if not mData then break end

        for _,sKey in pairs(lKeyAttr) do
            local mPro = {}
            for k,v in pairs(mPreData[sKey] or {}) do
                mPro[k] = v
            end

            for _, sEffect in ipairs(mData[sKey] or {}) do
                local sApply, sFormula = string.match(sEffect, "(.+)=(.+)")
                local iValue = tonumber(sFormula)
                if sApply and iValue then
                    local iValue = iValue + (mPro[sApply] or 0)
                    mPro[sApply] = iValue
                end
            end
            mData[sKey] = mPro
            mPreData[sKey] = mPro
        end
    end
    ret.skill = Require("skill/ride")
    return ret
end

local function RequireLog()
    local mData = {}
    mData.test = Require("log/test")
    mData.money = Require("log/money")
    mData.partner = Require("log/partner")
    mData.friend = Require("log/friend")
    mData.mail = Require("log/mail")
    mData.formation = Require("log/formation")
    mData.item = Require("log/item")
    mData.equip = Require("log/equip")
    mData.tempitem = Require("log/tempitem")
    mData.playerskill = Require("log/playerskill")
    mData.summon = Require("log/summon")
    mData.economic = Require("log/economic")
    mData.player = Require("log/player")
    mData.task = Require("log/task")
    mData.huodong = Require("log/huodong")
    mData.huodonginfo = Require("log/huodonginfo")
    mData.title = Require("log/title")
    mData.org = Require("log/org")
    mData.online = Require("log/online")
    mData.jjc = Require("log/jjc")
    mData.costcount = Require("log/costcount")
    mData.gm = Require("log/gm")
    mData.account = Require("log/account")
    mData.behavior = Require("log/behavior")
    mData.behaviorinfo = Require("log/behaviorinfo")
    mData.statistics = Require("log/statistics")
    mData.ride = Require("log/ride")
    mData.gamesys = Require("log/gamesys")
    mData.analy = Require("log/analy")
    mData.rank = Require("log/rank")
    mData.mtbi = Require("log/mtbi")
    mData.recovery = Require("log/recovery")
    mData.redpacket = Require("log/redpacket")
    mData.pay = Require("log/pay")
    mData.scene = Require("log/scene")
    mData.shop = Require("log/shop")
    mData.chat = Require("log/chat")
    mData.artifact = Require("log/artifact")
    mData.wing = Require("log/wing")
    mData.mentoring = Require("log/mentoring")
    mData.fabao = Require("log/fabao")
    mData.marry = Require("log/marry")
    mData.kuafu = Require("log/kuafu")
    return mData
end

local function OutPath(sFile)
    return string.format("%s/%s.lua", sOutPath, sFile)
end

local function RequireYibaoItemGroupRatio(mData)
    local mRet = {}
    for id, mInfo in pairs(mData) do
        for sKey, xValue in pairs(mInfo) do
            local iRatioLv = tonumber(string.match(sKey, "ratio_(%d+)"))
            if iRatioLv then
                local iRatio = xValue
                if 0 < xValue then
                    local mRatio = mRet[iRatioLv]
                    if not mRatio then
                        mRatio = {}
                        mRet[iRatioLv] = mRatio
                    end
                    mRatio[id] = iRatio
                end
            end
        end
    end
    return mRet
end

local function RequireAuctionGroup()
    local mGroup = {}
    for _, mInfo in ipairs(Require("economic/auction/group")) do
        if not mGroup[mInfo.group_id] then
            mGroup[mInfo.group_id] = {}
        end
        table.insert(mGroup[mInfo.group_id], mInfo)
    end
    return mGroup
end

local function RequireAuction()
    local mResult = {}
    mResult.sys_auction = Require("economic/auction/auction")
    mResult.text = Require("economic/auction/text")
    mResult.group = RequireAuctionGroup()
    return mResult
end

local function RequireAI()
    local mResult = {}
    mResult.action = Require("system/ai/action")
    mResult.target = Require("system/ai/target")
    return mResult
end

local function RequireWarConfig()
    local mResult = {}
    mResult = Require("system/warconfig/float")
    for key, val in pairs(Require("system/warconfig/ratio")) do
        mResult[key] = tonumber(val.ratio)
    end
    for key, info in pairs(Require("system/warconfig/damage_formula")) do
        mResult[info.key] = info.formula
    end
    for key, info in pairs(Require("system/warconfig/aura_effect")) do
        mResult[info.key] = info.ratio
    end
    return mResult
end

local function RequireChannelGroup(mInfo)
    local mResult = {}
    local mGroup = {}
    for id, mData in pairs(mInfo) do
        local l = mGroup[mData.channel_name]
        if not l then
            l = {}
            mGroup[mData.channel_name] = l
        end
        table.insert(l, id)
    end
    for name, lGroup in pairs(mGroup) do
        for _, id in ipairs(lGroup) do
            mResult[id] = {table.unpack(lGroup)}
        end
    end
    return mResult
end

local function RequireAllChannel(mInfo)
    local lChannels = {}
    for id, mData in pairs(mInfo) do
        table.insert(lChannels, id)
    end
    return lChannels
end

local function RequireCZKMixChannel(mInfo)
    local lChannels = {}
    for id, mData in pairs(mInfo) do
        if mData.desc == "czk_android" or mData.desc == "czk_ios" then
            table.insert(lChannels, id)
        end
        if mData.desc == "czk_tail" then
            table.insert(lChannels, id)
        end
    end
    return lChannels
end

local function RequireSMMixChannel(mInfo)
    local lChannels = {}
    for id, mData in pairs(mInfo) do
        if mData.desc == "sm_android" or mData.desc == "sm_ios" then
            table.insert(lChannels, id)
        end
    end
    return lChannels
end

local function RequirePlatChannel(mInfo)
    local mGroup = {}
    for id, mData in pairs(mInfo) do
        local l = mGroup[mData.desc]
        if not l then
            l = {}
            mGroup[mData.desc] = l
        end
        table.insert(l, id)
    end
    mGroup["czk_mix"] = RequireCZKMixChannel(mInfo)
    mGroup["sm_mix"] = RequireSMMixChannel(mInfo)
    return mGroup
end

local function ParseOpenConditions(mOpen)
    local mRet = {
        task_lock = {},
        p_grade = {},
    }
    for sSys, mInfo in pairs(mOpen) do
        local iTLock = mInfo.task_lock
        local iPGrade = mInfo.p_level
        if iTLock and iTLock > 0 then
            local lSysIds = mRet.task_lock[iTLock]
            if not lSysIds then
                lSysIds = {}
            end
            table.insert(lSysIds, sSys)
            table.sort(lSysIds)
            mRet.task_lock[iTLock] = lSysIds
        end

        local lSysIds = mRet.p_grade[iPGrade]
        if not lSysIds then
            lSysIds = {}
        end
        table.insert(lSysIds, sSys)
        table.sort(lSysIds)
        mRet.p_grade[iPGrade] = lSysIds
    end
    return mRet
end

local function ParseEverydayCondi(mEverydayTasks)
    local mRet = {}
    for id, mData in pairs(mEverydayTasks) do
        local lCondis = mData.condi
        for _, iCondi in ipairs(lCondis) do
            if not mRet[iCondi] then
                mRet[iCondi] = {}
            end
            mRet[iCondi][id] = true
        end
    end
    return mRet
end

local function ParseEverydaySpTask(mEverydayTasks)
    local mRet = {}
    for id, mData in pairs(mEverydayTasks) do
        local lCondis = mData.condi
        for _, iCondi in ipairs(lCondis) do
            if iCondi == 13 then
                mRet.condi_all_tasks = id
                break
            end
        end
    end
    return mRet
end

local function RequireWarTimeConfig()
    local mRet = {}
    for iPf, mShape2Time in pairs(Require("perform/pftime")) do
        local mInfo = {}
        for iShape, sTime in pairs(mShape2Time) do
            if sTime ~= "" then
                mInfo[iShape] = formula_string(sTime, {})
            end
            mInfo.id = nil
        end
        mRet[iPf] = mInfo
    end
    return mRet
end

local function RequireAttackedTime()
    local mRet = {}
    for _, mTime in ipairs(Require("perform/attackedtime")) do
        mRet[mTime.shape] = mTime.attackedtime 
    end
    return mRet
end

local function RequireVigo()
    local mRet = {}
    mRet.config = Require("system/vigo/config")
    mRet.text = Require("system/vigo/text")
    mRet.choose = Require("system/vigo/choose")
    mRet.other = Require("system/vigo/other")
    return mRet
end

local function RequireMoneyPoint()
    local mRet = {}
    mRet.base_leaderpoint_config = Require("system/point/base_leaderpoint_config")
    mRet.base_xiayipoint_config = Require("system/point/base_xiayipoint_config")
	mRet.base_chumopoint_config = Require("system/point/base_chumopoint_config")
	mRet.statistics_leaderpoint = Require("system/point/statistics_leaderpoint")
	mRet.statistics_xiayipoint = Require("system/point/statistics_xiayipoint")
	mRet.statistics_chumopoint = Require("system/point/statistics_chumopoint")
    mRet.limit_config = Require("system/point/limit_config")
    mRet.other_limit = Require("system/point/other_limit")
    mRet.text = Require("system/point/text")
    mRet.choose = Require("system/point/choose")
	mRet.scheduleid_2_chumotype = {}
	for sKey,mBase in pairs(mRet.base_chumopoint_config) do
		mRet.scheduleid_2_chumotype[mBase.schedule_id] = sKey
	end
    return mRet
end

local function RequireSummonSkill()
    local mData = Require("skill/summon")
    for id,m in pairs(mData) do
        if m["top_skill"] > 0 then
            mData[m["top_skill"]]["low_skill"] = id
        end
    end
    return mData
end

local function FormatStr2Second(sTime)
    local Y = string.sub(sTime, 1, 4)
    local m = string.sub(sTime, 6, 7)
    local d = string.sub(sTime, 9, 10)
    local H = string.sub(sTime, 12, 13)
    local M = string.sub(sTime, 15, 16)
    local S = string.sub(sTime, 18, 19)
    return os.time({year=Y, month=m, day=d, hour=H, min=M, sec=S})
end

local function RequireServerInfo()
    local mRet = {}
    for _,sKey in pairs({"serverinfo", "serverinfo_pro"}) do
        local mData = Require(sKey)
        for id, m in pairs(mData) do
            m["open_time"] = FormatStr2Second(m["open_time"])
            m["start_time"] = FormatStr2Second(m["start_time"])
            mRet[m["type"]] = mRet[m["type"]] or {}
            mRet[m["type"]][id] = m
        end
    end
    return mRet
end

local function ParseSummCarryLvSorted(mRequired)
    local mRet = {}
    local mCarry = {}
    for sid, mInfo in pairs(mRequired) do
        local iCarryLv = mInfo.carry
        mCarry[iCarryLv] = mCarry[iCarryLv] or {}
        mCarry[iCarryLv] [sid] = 1
    end
    local lSeq = table_key_list(mCarry)
    table.sort(lSeq, function(a,b) return a>b end)
    mRet.seq = lSeq
    mRet.detail = mCarry
    return mRet
end

local function RequireEngage()
    local mRet = RequireText("system/engage")
    mRet.config = Require("system/engage/config")
    mRet.engagetype = Require("system/engage/engagetype")
    local mData = Require("system/engage/upgrade")
    local mUpGrade = {}
    for _,v in pairs(mData) do
        local m = mUpGrade[v.type] or {}
        m[v.level] = v
        mUpGrade[v.type] = m
    end
    mRet.upgrade = mUpGrade
    return mRet
end

local function RequireArtifact()
    local mResult = {}
    mResult.text = Require("system/artifact/text")
    mResult.choose = Require("system/artifact/choose")
    mResult.config = Require("system/artifact/config")
    
    mResult.config[1].school2artifact = formula_string(mResult.config[1].school2artifact, {})
    
    local mEquipAttr = {}
    for iSid, mInfo in pairs(Require("system/artifact/equip_attr")) do
        local mTmp = {}
        for sKey, sAttr in pairs(mInfo) do
            if sKey ~= "equip_sid" and #sAttr > 0 then
                mTmp[sKey] = sAttr
            end
        end
        mEquipAttr[mInfo.equip_sid] = mTmp
    end
    mResult.equip_attr = mEquipAttr

    local mEquipScore = {}
    for iSid, mInfo in pairs(Require("system/artifact/equip_score")) do
        mEquipScore[mInfo.equip_sid] = mInfo.score
    end
    mResult.equip_score = mEquipScore

    local mUpgrade = {}
    for _, mInfo in ipairs(Require("system/artifact/upgrade")) do
        mUpgrade[mInfo.grade] = mInfo.exp_need
    end
    mResult.upgrade = mUpgrade

    local mUpgradeLimit = {}
    for _, mInfo in pairs(Require("system/artifact/upgrade_limit")) do
        mUpgradeLimit[mInfo.player_grade] = mInfo.equip_grade_limit
    end
    mResult.upgrade_limit = mUpgradeLimit

    local mStrength = {}
    for _, mInfo in ipairs(Require("system/artifact/strength")) do
        mStrength[mInfo.strength_lv] = mInfo.exp_need
    end
    mResult.strength = mStrength

    local mStrengthLimit = Require("system/artifact/strength_limit")
    local lKeyList = {}
    for iKey, mInfo in pairs(mStrengthLimit) do
        table.insert(lKeyList, iKey)
    end
    table.sort(lKeyList)
    mResult.strength_limit = {}
    for _, iGrade in ipairs(lKeyList) do
        table.insert(mResult.strength_limit, mStrengthLimit[iGrade])
    end

    local mStrengthEffect = {}
    for _, mInfo in pairs(Require("system/artifact/strength_effect")) do
        local mTmp = {}
        for sKey, sAttr in pairs(mInfo) do
            if type(sAttr) == "string" and #sAttr > 0 then
                mTmp[sKey] = sAttr
            end
        end
        mStrengthEffect[mInfo.equip_sid] = mTmp
    end
    mResult.strength_effect = mStrengthEffect

    local mSpiritInfo = {}
    for _, mInfo in pairs(Require("system/artifact/spirit_info")) do
        mSpiritInfo[mInfo.spirit_id] = mInfo
    end
    mResult.spirit_info = mSpiritInfo

    local mSpiritNum = {}
    for _, mInfo in pairs(Require("system/artifact/spirit_skill_num_priority")) do
        mSpiritNum[mInfo.spirit_id] = formula_string(mInfo.skill_num_priority, {})
    end
    mResult.spirit_skill_num_priority = mSpiritNum
    
    local mSkillPriority = {}
    for _, mInfo in pairs(Require("system/artifact/skill_priority")) do
        local mSchool = {}
        for sKey, iPriority in pairs(mInfo) do
            if sKey ~= "school" and iPriority > 0 then
                local iSkill = math.tointeger(string.sub(sKey, 7, -1))
                mSchool[iSkill] = iPriority
            end
        end
        mSkillPriority[mInfo.school] = mSchool
    end
    mResult.skill_priority = mSkillPriority

    local mSchoolSpiritEffect = {}
    for _, mInfo in pairs(Require("system/artifact/school_spirit_effect")) do
        local mSchool = {}
        for sKey, sEffect in pairs(mInfo) do
            if sKey ~= "school" then
                local iKey = math.tointeger(string.sub(sKey, 8, -1))
                mSchool[iKey] = sEffect
            end
        end
        mSchoolSpiritEffect[mInfo.school] = mSchool
    end
    mResult.school_spirit_effect = mSchoolSpiritEffect
    return mResult
end

local function RequireWing()
    local mResult = {}
    mResult.text = Require("system/wing/text")
    mResult.choose = Require("system/wing/choose")
    local mConfig = {}
    for idx, mInfo in ipairs(Require("system/wing/config")) do
        mConfig[idx] = mConfig[idx] or {}
        for sKey, rVal in pairs(mInfo) do
            if sKey == "item2goldcoin" then
                mConfig[idx][sKey] = formula_string(rVal, {})
            elseif sKey == "wing_effect" then
                local mSchoolEffect = {}
                for _, mVal in pairs(rVal) do
                    mSchoolEffect[mVal.school] = mVal.effect_id
                end
                mConfig[idx][sKey] = mSchoolEffect
            else
                mConfig[idx][sKey] = rVal
            end
        end
    end
    mResult.config = mConfig
    mResult.level_limit = Require("system/wing/level_limit")
    mResult.level_wing = Require("system/wing/level_wing")
    mResult.up_level = Require("system/wing/up_level")

    local mUpStar = {}
    for _, mInfo in ipairs(Require("system/wing/up_star")) do
        if not mUpStar[mInfo.level] then
            mUpStar[mInfo.level] = {}
        end
        mUpStar[mInfo.level][mInfo.star] = mInfo.up_star_exp
    end
    mResult.up_star = mUpStar
    
    mResult.wing_effect = Require("system/wing/wing_effect")
    mResult.wing_info = Require("system/wing/wing_info")
    for iWing, mWing in pairs(mResult.wing_info) do
        local mWingEffect = mWing.wing_effect
        local mSchoolEffect = {}
        for _, mInfo in pairs(mWingEffect) do
            mSchoolEffect[mInfo.school] = mInfo.effect_id
        end
        mWing.wing_effect = mSchoolEffect
    end

    return mResult
end

local function RequireFaBao()
    local mResult = {}
    mResult.text = Require("system/fabao/text")
    mResult.choose = Require("system/fabao/choose")
    mResult.info = Require("system/fabao/info")
    mResult.config = Require("system/fabao/config")
    mResult.combine = Require("system/fabao/combine")
    mResult.equip = Require("system/fabao/equip")
    mResult.decompose = Require("system/fabao/decompose")
    mResult.upgrade = Require("system/fabao/upgrade")
    mResult.xianling = Require("system/fabao/xianling")
    mResult.juexing_upgrade = Require("system/fabao/juexing_upgrade")
    mResult.hun = Require("system/fabao/hun")
    return mResult
end

local function RequireMentoring()
    local mResult = {}
    mResult.text = Require("system/mentoring/text")
    mResult.choose = Require("system/mentoring/choose")
    mResult.question = Require("system/mentoring/question")
    mResult.answer = Require("system/mentoring/answer")
    mResult.config = Require("system/mentoring/config")
    mResult.task = Require("system/mentoring/task")
    mResult.progress_reward = Require("system/mentoring/progress_reward")
    mResult.step_result = Require("system/mentoring/step_result")
    mResult.growup = Require("system/mentoring/growup")
    mResult.growup_reward = Require("system/mentoring/growup_reward")
    mResult.title_reward = Require("system/mentoring/title_reward")
    return mResult
end

local function RequireHotTopic()
    local mResult = {}
    mResult.config = Require("huodong/hottopic/config")
    mResult.sname2id = {}
    for id,mData in pairs(mResult.config) do
        mResult.sname2id[mData.sname] = id
    end
    return mResult
end

local M = {}

--daobiao begin

M.example = Require("example")
M.scene = Require("system/map/scene")
M.map = Require("system/map/map")
M.water_walk = Require("system/map/water_walk")
M.point = Require("system/role/point")
M.rolebasicscore = Require("system/role/rolebasicscore")
M.extrapoint = Require("system/role/extrapoint")
M.school = Require("system/role/school")
M.upgrade = RequireUpGrade()
M.servergrade = Require("system/role/servergrade")
M.washpoint = Require("system/role/washpoint")
M.roleprop = Require("system/role/roleprop")
M.roletype = Require("system/role/roletype")
M.toprole = Require("system/role/toprole")
--M.roletype_query = RequireQueryRoleType(M.roletype)
M.modelfigure = Require("system/role/model")
M.bianshen = Require("system/role/bianshen")
M.goldlimit = Require("system/role/goldlimit")
M.silverlimit = Require("system/role/silverlimit")
M.chubeiexplimit = Require("system/role/chubeiexplimit")
M.futureexplimit = Require("system/role/futureexplimit")
M.global = Require("global")
M.mail = Require("mail")
M.grade_mail = Require("grade_mail")

M.item = RequireItem()
M.itemtext = {}
M.itemtext.text = Require("item/text")
M.itemtext.choose = Require("item/choose")
-- 这个是装备等级
M.equiplevels = RequireEquipLevels(M.item)
-- 这个是装备品质quality
M.equiplevel = Require("system/dazao/equiplevel")
M.equipattr = Require("system/dazao/equipattr")
M.equipattach = RequireEquipAttach()
M.equipse = RequireEquipSe()
M.equipsk = RequireEquipSK()
M.equipglobal = Require("system/dazao/global")
M.equipscore = Require("item/equipscore")
M.equipposname = Require("item/equippos")
M.equipweapon = RequireWeapon()
M.strengthscore = Require("item/strengthscore")
M.summonskillgroup = Require("item/summonskillgroup")
M.summonequipratio = Require("item/summonequipratio")
M.equip_level = Require("item/equip_level")
M.strength = RequireStrength()
M.strengthmaster = RequireStrengthMaster()
M.strengthmaterial = RequireStrengthMaterial()
M.strengthratio = Require("system/dazao/strength_ratio")
M.equipbreak = RequireEquipBreak()
M.washequip = RequireWashEquip()
M.shenhuneffect = Require("system/dazao/shenhuneffect")
M.shenhunmerge = Require("system/dazao/shenhunmerge")
M.fuhunextra = RequireFunHunExtra()
M.fuhunpoint = Require("system/dazao/fuhunpoint")
M.equipfenjie = RequireEquipFenjie()
M.fenjieku = RequireFenjieKu()
M.dazao = RequireDazao()
M.fuhuncost = Require("system/dazao/fuhuncost")
M.itemcompound = Require("item/itemcompound")
M.itemexchange = Require("item/itemexchangeserver")
M.hunshi = RequireHunShi()
M.wenshi = RequireWenShi()


M.global_npc = Require("npc/global_npc")
M.school_npc = Require("npc/school_npc")
M.npc_menu_option = Require("npc/menu_option")
M.dialog_npc = Require("npc/dialog_npc")
M.npcgroup = Require("npc/npcgroup")

M.task_type = Require("task/tasktype")
M.task = RequireTask()
M.task_ext = RequireTaskExt()
M.everyday_task = {}
M.everyday_task.task = Require("task/everydaytask")
M.everyday_task.condi = ParseEverydayCondi(M.everyday_task.task)
M.everyday_task.sptask = ParseEverydaySpTask(M.everyday_task.task)

M.huodong = RequireHuodong()
M.fight = RequireFight()
M.reward = RequireReward()
-- giftpack表特殊处理
M.reward.giftpack = {}
M.reward.giftpack.itemreward = RequireItemRewardGroupIdxed("reward/giftpack_itemreward")

M.shimentaskratio = RequireShimenRatio()
M.shimenlv = Require("task/shimen/shimenlv")

M.scenemonster = Require("huodong/trapmine/scenemonster")

M.itemgroup = Require("item/itemgroup")
M.itemfilter = RequireItemFilter("item/itemfilter")
M.equipfixed = Require("item/equipfixed")
M.scenegroup = Require("system/map/scenegroup")
M.team = {}
M.team.autoteam = Require("system/team/autoteam")
M.team.text  = Require("system/team/text")
M.team.choose = Require("system/team/choose")
M.team.warcmd = Require("system/team/warcmd")
M.chatconfig = Require("system/chat/chatconfig")
M.chuanyin = Require("system/chat/chuanyin")
M.chattext = RequireText("system/chat")
M.gonggao = Require("system/chat/gonggao")
M.chuanwen = Require("system/chat/chuanwen")
M.summon = {}
local mSummInfo = Require("system/summon/summoninfo")
M.summon.info = mSummInfo
M.summon.sorted_carry_lv = ParseSummCarryLvSorted(mSummInfo)
M.summon.grow = Require("system/summon/grow")
M.summon.washcost = Require("system/summon/washcost")
M.summon.skill = RequireSummonSkill()
M.summon.skillcost = Require("system/summon/skillcost")
M.summon.score = Require("system/summon/score")
M.summon.autopoint = Require("system/summon/autopoint")
M.summon.store = Require("system/summon/store")
M.summon.xiyou = Require("system/summon/xiyou")
M.summon.bianyi = Require("system/summon/bianyi")
M.summon.aptitcombine = Require("system/summon/aptitcombine")
M.summon.skcntcombine = Require("system/summon/skcntcombine")
M.summon.aptitudepellet = Require("system/summon/aptitudepellet")
M.summon.fixedproperty = Require("system/summon/fixedproperty")
M.summon.config = Require("system/summon/config")
M.summon.summongroup = Require("system/summon/summongroup")
M.summon.text = RequireText("system/summon")
M.summon.calformula = Require("system/summon/calformula")
M.summon.shenshouexchange = Require("system/summon/shenshouexchange")
M.summon.shenshouadvance = Require("system/summon/shenshouadvance")
M.summon.xyshenshouadvance = Require("system/summon/xyshenshouadvance")
M.summon.xyzhenshouadvance = Require("system/summon/xyzhenshouadvance")
M.summon.escape = Require("system/summon/escape")
M.schedule = {}
M.schedule.schedule = Require("schedule/schedule")
M.schedule.active = Require("schedule/activereward")
M.schedule.week = Require("schedule/week")

M.redpacket = {}
M.redpacket.basic = Require("system/redpacket/basic")
M.redpacket.type = Require("system/redpacket/type")
M.redpacket.channel = Require("system/redpacket/channel")
M.redpacket.se = Require("system/redpacket/se")
M.redpacket.cashtype = Require("system/redpacket/cashtype")
M.redpacket.personnum = Require("system/redpacket/personnum")
M.redpacket.text = Require("system/redpacket/text")

M.tempitem = {}
M.tempitem.text = Require("system/tempitem/text")

M.ranse = {}
M.ranse.text = Require("system/ranse/text")
M.ranse.basic = Require("system/ranse/basic")
M.ranse.shizhuang = Require("system/ranse/shizhuang")
M.ranse.clothes = Require("system/ranse/clothes")
M.ranse.summon = Require("system/ranse/summon")
M.ranse.hair = Require("system/ranse/hair")
M.ranse.sz_basic = Require("system/ranse/sz_basic")
M.ranse.pant = Require("system/ranse/pant")
M.ranse.config = Require("system/ranse/config")
M.ranse.resume_reason = Require("system/ranse/resume_reason")
M.ranse.ranse_part = Require("system/ranse/ranse_part")

M.recovery = {}
M.recovery.item = Require("system/recovery/recoveryitem")
M.recovery.sum = Require("system/recovery/recoverysum")

M.promote={}
M.promote.score = Require("system/promote/score")
M.promote.warfail = Require("system/promote/warfail")
M.promote.judge = Require("system/promote/judge")
M.promote.biaozhun = Require("system/promote/biaozhun")

M.perform = RequirePerform()
M.buff = Require("buff/buff")
M.bufflimit = Require("buff/bufflimit")
M.performratio = Require("perform/performratio")
M.skill = RequireSkill()
M.cultivatelevel = Require("skill/level_limit")
M.cultivateorglimit = Require("skill/org_level_limit")
M.cultivatelearntime = Require("skill/learn_time")
M.passive_cost = Require("skill/passive_cost")
M.auto_perform = Require("perform/auto_perform")
M.bosswar_pos = Require("fight/bosswar_pos")

M.npcstore = RequireNPCStore("economic/store/npcstore")
M.goldcoinstore = Require("economic/store/goldcoinstore")
M.goldstore = Require("economic/store/goldstore")
M.silverstore = Require("economic/store/silverstore")
M.exchangemoney = Require("economic/store/exchangemoney")
M.limittimediscount = Require("economic/store/limittimediscount")
M.storemoneytype = Require("economic/store/storemoneytype")

M.shop = {}
M.shop.wuxun = Require("economic/shop/wuxun")
M.shop.jjcpoint = Require("economic/shop/jjcpoint")
M.shop.joyexpenseold = Require("economic/shop/joyexpenseold")
M.shop.joyexpensenew = Require("economic/shop/joyexpensenew")
M.shop.leaderpoint = Require("economic/shop/leaderpoint")
M.shop.xiayipoint = Require("economic/shop/xiayipoint")
M.shop.summonpoint = Require("economic/shop/summonpoint")
M.shop.rplgoldcoin = Require("economic/shop/rplgoldcoin")
M.shop.chumopoint = Require("economic/shop/chumopoint")
M.shop.text = Require("economic/shop/text")

M.fastbuy = RequireFastBuyItem()

M.stall = RequireStall()

M.itemcolor = Require("itemcolor")
M.othercolor = Require("othercolor")
M.state = {}
M.state.text = Require("buff/text")
M.state.state = Require("buff/state")
M.open = Require("open")
M.open_condi = ParseOpenConditions(M.open)
M.attrname = Require("system/role/attrname")
M.partner = RequirePartner()
M.ghostname = RequireGhostName()
M.friend = {}
M.friend.text = Require("system/friend/text")
M.friend.flower = Require("system/friend/flower")
M.friend.effect = Require("system/friend/effect")
M.org = RequireOrg()
M.title = RequireTitle()
M.touxian = RequireTouxian()
M.rank = RequireRank("system/rank/rankinfo")
M.rankreward = Require("system/rank/reward")
M.upvote = Require("system/role/upvote")
M.formation = RequireFormation()
M.jjc = RequireJJC()
M.gamepush = Require("system/gamepush/gamepush")
M.text = RequireText()
M.showid = RequireShowId()
M.orgskill = {}
M.orgskill.skill = Require("system/orgskill/skill")
M.orgskill.refine = Require("system/orgskill/refine")
M.orgskill.upgrade = Require("system/orgskill/upgrade")
M.guild = RequireGuild()
M.lottery = RequireItemReward("reward/lottery")
M.developer = Require("system/developer/basicinfo")
M.shootcrapsonline=Require("huodong/shootcraps/onlinetime")

M.yibao_config = {}
M.yibao_config.star_info = Require("task/yibao/star_info")
M.yibao_config.type_cnt_ratio = Require("task/yibao/type_cnt_ratio")
local mSeekitemGroupData = Require("task/yibao/seekitem_group_ratio")
M.yibao_config.seekitem_group_data = mSeekitemGroupData
M.yibao_config.seekitem_group_ratio = RequireYibaoItemGroupRatio(mSeekitemGroupData)
M.yibao_config.seekitem_group_old_ver = Require("task/yibao/seekitem_group_old_ver")
M.yibao_config.seekitem_group_lv = Require("task/yibao/seekitem_group_lv")

M.orgtask = {}
M.orgtask.taskrand = Require("task/orgtask/task_random")
M.orgtask.starrand = Require("task/orgtask/star_random")

M.xuanshang_config = Require("task/xuanshang/xuanshang_config")
M.xuanshang_limit = Require("task/xuanshang/xuanshang_limit")

M.jyfuben = {}
M.jyfuben.grouptask = Require("task/jyfuben/grouptask")
M.jyfuben.floorreward = Require("task/jyfuben/floorreward")

M.instruction = Require("instruction")

M.zhenmo = RequireZhenmoConfig()

M.qte = Require("qte/qte")
M.story_anime_qte = RequireStoryAnimeQte()
M.fuben = RequireFubenConfig()
M.random_npcname = RequireRandNpcName()
M.random_rolename = RequireRandRoleName()
M.gradegift = Require("system/role/gradegift")
M.preopen = Require("preopen")
M.openbox = {}
M.openbox.text = RequireText("system/openbox")
M.ride = RequireRide()
M.log = RequireLog()
M.auction = RequireAuction()
M.ai = RequireAI()
M.warconfig = RequireWarConfig()
M.newbieguide = {}
M.newbieguide.newbie_summon = Require("system/guide/newbie_summon")
M.newbieguide.newbie_equip = Require("system/guide/newbie_equip")
M.newbieguide.newbie_upgrade = Require("system/guide/newbie_upgrade")
M.pfconflict = Require("perform/pfconflict")
M.bulletbarrage = {}
M.bulletbarrage.text = Require("system/barrage/text")
M.pay = Require("pay/pay")
M.demichannel = Require("demichannel")
M.channelgroup = RequireChannelGroup(M.demichannel)
M.allchannel = RequireAllChannel(M.demichannel)
M.platchannel = RequirePlatChannel(M.demichannel)
M.h7dchannel = Require("h7dchannel")
M.h7dchannelgroup = RequireChannelGroup(M.h7dchannel)
M.magictimedata = RequireWarTimeConfig()
M.attackedtime = RequireAttackedTime()
M.vigo = RequireVigo()
M.moneypoint = RequireMoneyPoint()
M.serverinfo = RequireServerInfo()
M.hdcontrol = Require("huodong/hd_control")
M.engage = RequireEngage()
M.artifact = RequireArtifact()
M.wing = RequireWing()
M.fabao = RequireFaBao()
M.mentoring = RequireMentoring()
M.hdhottopic = RequireHotTopic()
M.kuafu = Require("system/kuafu/config")
--daobiao end
CheckRaiseNpcTypes()
-- daobiao check end

local s = dumpapi(M)
local f = io.open(OutPath("data"), "wb")
f:write(s)
f:close()
