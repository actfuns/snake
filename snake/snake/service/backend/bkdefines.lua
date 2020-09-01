--import module
PLAYER_SCHOOL = {
    [1] = "蜀山",
    [2] = "金山寺",
    [3] = "太初",
    [4] = "瑶池",
    [5] = "青城山",
    [6] = "妖神宫",
}

CHANNEL_MAP = {
    [""] = "空渠道",
    ["pc"]= "PC测试",
    ["uc"] = "UC",
    ["360"] = "360",
}

-- 游戏log 类型
GAME_LOG_MAP = {
    {"player", "玩家日志"},
    {"playerskill", "玩家技能"},
    {"partner", "伙伴日志"},
    {"formation", "阵法日志"},
    {"economic", "商城购买"},
    {"friend", "好友日志"},
    {"huodong", "活动日志"},
    {"item", "物品日志"},
    {"jjc", "竞技场日志"},
    {"mail", "邮件日志"},
    {"money", "货币消耗日志"},
    {"online", "在线人数"},
    {"org", "帮派日志"},
    {"ride", "坐骑日志"},
    {"summon", "宠物日志"},
    {"task", "任务日志"},
    {"title", "称谓日志"},
    {"redpacket", "红包日记"},
    {"recovery", "物品回收"},
    {"huodonginfo", "活动信息"},
    {"chat", "聊天禁言"},
    {"equip", "装备日志"},
    {"tempitem", "临时背包"},
    {"pay", "充值相关"},
    {"shop", "积分商城"},
    {"artifact", "神器系统"},
    {"wing", "羽翼系统"},
    {"fabao", "法宝系统"},
}

-- 中英映射
EN_2_CH_MAP = {
    exp_overflow = "经验溢出",
    story = "主线任务",
    preopen = "升级礼包",
    shimen = "门派修行",
    ghost = "抓鬼",
    fengyao = "封妖",
    biwu = "比武",
    fuben = "副本",
    mengzhu = "盟主",
    treasure = "挖宝",
    orgcampfire = "帮派篝火",
    fumo = "伏魔",
    stall_withdraw = "摆摊取现",
    devil = "天魔",
    guild_sell = "商会出售",
    auction_price = "单个摆摊",
    auction_all_price = "摆摊全部",
}

function AnalyTime(sTime)
    local year,month,day = string.match(sTime,"(%d+)-(%d+)-(%d+)")
    year,month,day = tonumber(year),tonumber(month),tonumber(day)
    return year,month,day
end

function AnalyTimeStamp(sTime)
    local year,month,day = string.match(sTime,"(%d+)-(%d+)-(%d+)")
    year,month,day = tonumber(year),tonumber(month),tonumber(day)
    return os.time({year = year,month = month,day = day,hour=0,min=0,sec=0})
end

function AnalyTimeStamp2(sTime)
    if not sTime or sTime == "" then
        return
    end
    local year,month,day,hour,min,sec = string.match(sTime,"(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    year,month,day,hour,min,sec = tonumber(year),tonumber(month),tonumber(day),tonumber(hour),tonumber(min),tonumber(sec)
    return os.time({year = year,month = month,day = day,hour=hour,min=min,sec=sec})
end

function FormatTime(iTime)
    local m = os.date("*t", iTime)
    return string.format("%04d-%02d-%02d",m.year,m.month,m.day)
end

function FormatTimeToSec(iTime)
    local m = os.date("*t", iTime)
    return string.format("%04d-%02d-%02d %02d:%02d:%02d",m.year,m.month,m.day,m.hour,m.min,m.sec)
end

function GetDateInfo(iTime)
    local mDate = os.date("*t", iTime)
    return mDate.year,mDate.month,mDate.day
end

ServerName = {
    [1] = "开发服",
}

function GetServerName(iServer)
    return ServerName[iServer] or "未知服务器"
end

function GetYearMonthList(iStartTime, iEndTime)
    local iStartYear,iStartMonth = GetDateInfo(iStartTime)
    local iEndYear,iEndMonth = GetDateInfo(iEndTime)

    local lRet = {}
    local iMonth = iStartMonth
    for i = iStartYear, iEndYear do
        for j = 1, 12 do
            if i == iStartYear then
                if j >= iStartMonth then
                    table.insert(lRet, {i, j})        
                end
            elseif i == iEndYear then
                if j <= iEndMonth then
                    table.insert(lRet, {i, j}) 
                end
            else
                table.insert(lRet, {i, j})
            end 
        end
    end
    return lRet
end

function GetChByEn(sKey)
    return EN_2_CH_MAP[sKey] or sKey
end
