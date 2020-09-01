WAR_ACTOR_TYPE = {
    PLAYER = 1,
    SUMMON = 2,
    PARTNER = 3,
    MONSTER = 4,
    LEADER = 5,
    LEADER_SUMMON = 6,
}

WAR_TIMING = {
    WAR_START = 11,
    ROUND_START = 12, -- 玩家角色下指令之后
    ROUND_END = 13,
    BEFORE_ACT = 14, -- 角色执行具体行动前
    X_ROUND_START = 15,
    X_ROUND_END = 16,
    X_ROUND_BEFORE_ACT = 17,
    MONSTER_X_SUB_HP_TO_Y_PERCENT = 18,
    ESCAPE = 19,
}