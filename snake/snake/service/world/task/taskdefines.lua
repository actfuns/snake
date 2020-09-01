SHIMEN_INFO = {
    MIN_GRADE = 15,           -- 师门最小领取等级
    LIMIT_RINGS = 20,         -- 师门限制一天多少环
    RINGS_PER_ROUND = 10,     -- 师门一轮多少环
    WEEKLY_REWARD_RING = 100, -- 师门每周第x次奖励
    WEEKLY_REWARD_TBL = 2001, -- 师门周奖励表
    DAILY_REWARD_SP_RING_TBL_1 = 3001, -- 师门每日特别环奖励表（第10环）
    DAILY_REWARD_SP_RING_TBL_2 = 3002, -- 师门每日特别环奖励表（第20环）
}

GHOST_INFO = {
    ROUND_RINGS = 10, -- 一轮的次数
}

SCHOOLPASS_INFO = {
    ROUND_RINGS = 7, -- 一轮的次数
}

YIBAO_INFO = {
    MAIN_TASK = 70000, -- 主任务（父任务）
    MAX_TIMES = 1, -- 每天最大次数
    SUB_TASK_CNT = 10, -- 子任务数量
    MAX_HELP_GATHER_REQ_TASKS = 2, -- 最多请求异宝寻物的任务数量
    MAX_EXPLORE_STAR = 5, -- 最大探险星级
    MAX_HELP_GATHER_TIMES = 10, -- 协助寻物次数
    MAX_HELP_EXPLORE_TIMES = 5, -- 协助探险次数
    HELP_EXPLORE_REWARD_MAIL = 2008, -- 协助探险奖励邮件ID
}

YIBAO_KIND = {
    MAIN = 1,
    EXPLORE = 2,
    FIND_ITEM = 3,
    QTE = 4,
}

-- 任务分类(type项)
TASK_KIND      = {
    TEST       = 1,  -- 测试
    TRUNK      = 2,  -- 主线
    BRANCH     = 3,  -- 支线
    SHIMEN     = 4,  -- 师门
    GHOST      = 5,  -- 金刚伏魔
    YIBAO      = 6,  -- 异宝
    FUBEN      = 7,  -- 副本
    SCHOOLPASS = 8,  -- 门派试炼
    ORGTASK    = 9,  -- 帮派任务
    LINGXI     = 10, -- 灵犀任务
    GUESSGAME  = 11, -- 火眼金睛
    JYFUBEN    = 12, -- 精英副本
    LEAD       = 13, -- 引导任务
    RUNRING    = 14, -- 跑环任务(别名：任务链)
    BAOTU      = 15, -- 宝图任务
    XUANSHANG  = 16, -- 悬赏任务
    ZHENMO     = 17, -- 镇魔塔
    IMPERIALEXAM = 18, -- 天问答题
    TREASURECONVOY = 19, -- 秘宝护送
}

-- 任务事件
EVENT = {
    UNLOCK_TAG = 1,   -- 主要是主线完成解锁标记
    LOCK_TAG = 2,     -- 主要是主线完成加锁标记
    ADD_TASK = 3,     -- 添加任务
    PRE_DEL_TASK = 4, -- 准备删除任务
    DEL_TASK = 5,     -- 删除任务后
}

TASK_ERROR = {
    GRADE_LIMIT      = 1,
    TEAM_SIZE_LIMIT  = 2,
    PRE_LOCKED       = 3,
    ROLE_SHAPE_LIMIT = 4,
    SCHOOL_LIMIT     = 5,
    HAS_TASK_LIMIT   = 6,
}

function GetErrMsg(iErr)
    if iErr == TASK_ERROR.GRADE_LIMIT then
        return "等级不足"
    elseif iErr == TASK_ERROR.TEAM_SIZE_LIMIT then
        return "队伍人数不足"
    elseif iErr == TASK_ERROR.PRE_LOCKED then
        return "前置任务未完成"
    elseif iErr == TASK_ERROR.ROLE_SHAPE_LIMIT then
        return "角色不符"
    elseif iErr == TASK_ERROR.SCHOOL_LIMIT then
        return "门派不符"
    elseif iErr == TASK_ERROR.HAS_TASK_LIMIT then
        return "你已经领取此任务了"
    end
    return ""
end

TASK_ACTION = {
    ADD = 100,
    RELEASE = 101,
    DONE = 102,
    REMOVE = 103,
}

EXTEND_OPTION_STATE = {
    NORMAL = 0,    -- 常规
    GREY = 1,      -- 灰
    HIGHLIGHT = 2, -- 高亮
}

TASK_SYS_OPEN = {
    ["story"] = "BORN_STORY_TASK",
    ["baotu"] = "BAOTU",
    ["ghost"] = "ZHUAGUI",
    ["runring"] = "TASKCHAIN",
    ["xuanshang"] = "XUANSHANG",
}
