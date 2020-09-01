
ORG_POSITION = {
    LEADER = 1,     --帮主
    DEPUTY = 2,     --副帮主
    ELDER = 3,      --长老
    CARTER = 4,     --车夫
    FAIRY = 5,      --宝贝
    MEMBER = 6,      --帮众
    XUETU = 7,      --学徒
}

ORG_HONOR = {
    MOSTPOINT = 1,     --执剑使 
    STRONGEST = 2,     --客卿
    ELITE = 3,      --精英
}

ORG_APPLY = {
    APPLY = 0,     
    INVITED = 1,  
}

ORG_AUTHORITY = {
    DEALAPPLY = 1,  --处理申请
    KICKOUT = 2,    --剔出成员
    CHANGEAIM = 3,  --修改宣言
    ASSIGN = 4,     --任命
    DEMISE = 5,     --禅让帮主
    BUILD = 6,      --升级建筑
    OPENHD = 7,     --开启活动
    SILENT = 8,     --禁言
    MEMBER = 9,     --转正
}

ORG_POT_AUTH = {
    [ORG_POSITION.LEADER] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
    [ORG_POSITION.DEPUTY] = {1, 1, 1, 1, 0, 1, 1, 1, 1},
    [ORG_POSITION.ELDER] = {1, 1, 1, 1, 0, 0, 0, 1, 0},
}

-- ORG_RESPOND_TIME = 10 * 60
-- ORG_NEED_RESPOND_CNT = 1
-- ORG_SPREAD_TIME = 30 * 60
-- ORG_APPLY_LEADER_TIME = 24 * 3600
ORG_DEL_XUETU_TIME = 2 * 24 * 3600
-- ORG_LEADER_OFFINE_TIME = 7 * 24 * 3600
ORG_MUL_APPLY_TIME = 30 * 60
-- ORG_APPLY_VAILD_TIME = 5 * 60 

-- 帮派成就类型
ORG_ACH_TYPE = {
    ORG_LEVEL = 1,                                                  -- 帮派达到指定等级
    BUILD_LEVEL = 2,                                               -- 指定建筑达到指定等级
    ALL_BUILD_LEVEL = 3,                                        -- 全部建筑达到指定等级
    MEMBER_CNT = 4,                                             -- 成员数达到指定的数量   
    MEM_GRADE_CNT = 5,                                       -- 指定成员等级达到指定的数量
    CASH_CNT = 6,                                                   -- 资金达到指定的值
    BOOM_VAL = 7,                                                  -- 繁荣度到达指定值
    BOOM_MORE_DAY = 8,                                      -- 繁荣度连续指定天到达指定值 
}

NEW_ACH_FUNC = {
    [ORG_ACH_TYPE.ORG_LEVEL] = "NewAchTargetVal",
    [ORG_ACH_TYPE.BUILD_LEVEL] = "NewAchBuildLevel",
    [ORG_ACH_TYPE.ALL_BUILD_LEVEL] = "NewAchTargetVal",
    [ORG_ACH_TYPE.MEMBER_CNT] = "NewAchTargetVal",
    [ORG_ACH_TYPE.MEM_GRADE_CNT] = "NewAchMemGradeCnt",
    [ORG_ACH_TYPE.CASH_CNT] = "NewAchCashCnt",
    [ORG_ACH_TYPE.BOOM_VAL] = "NewAchTargetVal",
    [ORG_ACH_TYPE.BOOM_MORE_DAY] = "NewAchBoomMoreDay",
}

-- 一键申请个数
MULTI_APPLY_NUM = 20

-- 申请上限
APPLY_MAX_NUM = 100
