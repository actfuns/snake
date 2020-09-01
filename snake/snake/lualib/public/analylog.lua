local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"
local gdefines = import(lualib_path("public.gamedefines")) 
local analy = import(lualib_path("public.dataanaly"))

-- sType: 定义下(activate_ride 坐骑激活)
-- sSubtype: 子类型可以为空
-- 玩家系统分析
function LogSystemInfo(oPlayer, sType, sSubtype, mCost)
    local mLog = {}
    mLog["type"] = sType
    mLog["change_detail"] = tostring(sSubtype or "")
    mLog["consume_detail"] = mCost or ""
    LogBaseInfo(oPlayer, "PlayerSystemChange", mLog)
end

-- 更新宠物列表(0 更新，1 标识增加，2 删除)
function LogPlayerSummonInfo(oPlayer, oSummon, iOperate)
    LogBaseInfo(oPlayer, "PlayerSummon", {
        summon_id = oSummon:TraceRealNo() or 0,
        sid = oSummon:TypeID(),
        operate = iOperate,
        summ_level = oSummon:GetGrade(),
        summ_score = oSummon:GetScore()
    })
end

-- 购买商品记录
function LogMallBuy(oPlayer, iShop, iMoneyType, iSid, iAmount, iTotal)
    local mLog = oPlayer:BaseAnalyInfo()
    mLog["yuanbao_before"] = 0
    mLog["consume_yuanbao"] = 0
    mLog["yuanbao_bd_before"] = 0
    mLog["consume_yuanbao_bd"] = 0
    mLog["shop_id"] = iShop
    mLog["shop_sub_id"] = 1
    mLog["currency_type"] = iMoneyType
    mLog["item_id"] = iSid
    mLog["price"] = iPrice
    mLog["num"] = iAmount
    mLog["consume_count"] = iTotal
    mLog["remain_currency"] = 0
    analy.log_data("MallBuy", mLog)
end

function LogMarryInfo(oPlayer, iMale, sMale, iFemale, sFemale, iMarryType, iOperate)
    LogBaseInfo(oPlayer, "MarryInfo", {
        male_pid = iMale,
        male_name = sMale,
        female_pid = iFemale,
        female_name = sFemale,
        marry_type = iMarryType,
        operate = iOperate,
    })
end

-- 日志说明：记录玩家日常玩法信息；            
-- iOperate 1 参与 2 完成
function LogWanFaInfo(oPlayer, sType, iWanFa, iOperate)
    LogBaseInfo(oPlayer, "WanFaInfo", {
        wf_type = sType,
        wf_id = iWanFa or 0,
        operate = iOperate,
    })
end

-- 日志说明：记录玩家战斗信息；          
-- operate int 1 参与 2 胜利 3 失败 4 逃跑
function LogWarInfo(oPlayer, sType, iStage, iOperate)
    LogBaseInfo(oPlayer, "WarInfo", {
        stage_type = sType or "",
        stage_id = iStage or 0,
        operate = iOperate,
    })
end

-- 日志说明: 禁言信息
function LogBanChat(oPlayer, sMsg, iRule)
    LogBaseInfo(oPlayer, "BanChat", {
        chat_msg = sMsg,
        rule_id = iRule,
    })
end

-- 背包日志 
function LogBackpackChange(oPlayer, iOperate, iSid, iAmount, sReason)
    local mAnalyLog = oPlayer:BaseAnalyInfo()
    mAnalyLog["operation"] = iOperate
    mAnalyLog["item_id"] = iSid
    mAnalyLog["num"] = iAmount
    mAnalyLog["remain_num"] = oPlayer:GetItemAmount(iSid)
    mAnalyLog["reason"] = sReason
    analy.log_data("BackpackChange", mAnalyLog)
end

-- 分析日志统一方法
function LogBaseInfo(oPlayer, sFile, mLog)
    mLog = mLog or {}
    analy.log_data(sFile, table_combine(oPlayer:BaseAnalyInfo(), mLog))
end

function FastCostLog(mFastCost)
    local mCostLog = {}
    if mFastCost["goldcoin"] then
        mCostLog[gdefines.MONEY_TYPE.GOLDCOIN] = mFastCost["goldcoin"]
    end
    if mFastCost["silver"] then
        mCostLog[gdefines.MONEY_TYPE.SILVER] = mFastCost["silver"]
    end
    if mFastCost["gold"] then
        mCostLog[gdefines.MONEY_TYPE.GOLD] = mFastCost["gold"]
    end
    for iSid, iAmount in pairs(mFastCost["item"]) do
        mCostLog[iSid] = iAmount
    end
    return mCostLog
end

-- 不递归
function table_format_concat(m)
    if type(m) ~= "table" then return m end

    local s
    for k,v in pairs(m) do
        if not s then
            s = string.format("%s+%s", k, v)
        else
            s = string.format("%s&%s+%s", s, k, v)
        end
    end
    return s or ""
end
