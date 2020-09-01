DEAL_TICK_MS = 500 -- 每跳处理时间间隔(毫秒)
DEAL_PLAYERS_PER_TICK = 50 -- 每跳处理玩家数（主要考虑发经验引发升级）
MAX_ROOM_PLAYER_CNT = 500 -- 场景较小，考虑视觉效果和机器压力

ERR_USE_SKILL = {
    IN_CD = 1,
    TARGET_FAIL = 2,
    GIVE_UP = 3, -- 弃权不能使用技能
    IN_SHIELD = 4, -- 金钟罩中
    TIME_ERR = 5, -- 不合理的使用时机
    TARGET_OFFLINE = 6, -- 目标不在线
    NO_SKILL = 10, -- 没有技能
}

SKILL_ID = {
    SHIELD = 1001, -- 金钟罩
    KICK = 1002, -- 无影脚
}

STATE_ID = {
    SHIELD = 1008, -- 金钟罩
}
