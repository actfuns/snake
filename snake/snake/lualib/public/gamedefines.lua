--import module
local geometry = require "base.geometry"

SCENE_GRID_DIS_X = 10
SCENE_GRID_DIS_Y = 5
SCENE_PLAYER_SEE_LIMIT = 40

SERVER_GRADE_LIMIT = 100

QUEUE_CNT = 4000
MAX_PLAYER_CNT = 6000

USE_C_SUM = true
USE_NEW_C_SUM = true

-- c层同步定义
SUM_DEFINE = {
    MO_ATTR_ADD = 0,
    MO_ATTR_BASE_R = 1,
    MO_ATTR_POINT = 2,
    MO_BASE = 3,
    MO_PARTNER = 4,
    MO_RIDE = 5,
    MO_TOUXIAN = 6,
    MO_SKILL_MGR = 7,
    MO_SKILL_MGR_R = 8,
    MO_EQUIP_MGR = 9,
    MO_EQUIP_MGR_R = 10,
    MO_RIDE_MGR = 11,
    MO_RIDE_MGR_R = 12,
    MO_TITLE_MGR = 13,
    MO_TITLE_MGR_R = 14,
    MO_FABAO_MGR = 15,
    MO_FABAO_MGR_R = 16,
}

ERRCODE = {
    ok = 0,
    common = 1,
    login_ks = 2,
--login
    in_login = 1001,
    in_logout = 1002,
    not_exist_player = 1003,
    name_exist = 1004,
    in_maintain = 1005,
    reenter = 1006,
    error_id = 1007,
    role_max_limit = 1008,
    error_account_env = 1009,
    script_error = 1010,
    invalid_token = 1011,
    invalid_role_token = 1012,
    error_app_version = 1013,
    pre_create_role = 1014,
    invalid_platform = 1015,
    invalid_channel = 1016,
    kickout = 1017,
    error_server_key = 1018,
    not_start_ks = 1019
}

LOGIN_CONNECTION_STATUS = {
    no_account = 1,
    in_login_account = 2,
    login_account = 3,
    in_login_role = 4,
    login_role = 5,
    in_create_role = 6,
}

GAME_CHANNEL = {
    develop = "pc",        -- 开发版本
}

PUBLISHER = {
    none = 0,    -- 无（全）发行
    czk = 1,    -- 晨之科
    sm = 2,     -- 手盟
}

PLATFORM = {
    android = 1,
    rootios = 2,
    ios = 3,
    pc = 4
}

PLATFORM_DESC = {
    [1] = "ANDROID", -- 安卓
    [2] = "ROOTIOS", -- 越狱ios
    [3] = "IOS", -- ios
    [4] = "PC", -- windows
}

PLAYER_SCHOOL = {
    SHUSHAN = 1,    --蜀山
    JINSHAN = 2,    --金山
    XINGXIU = 3,    --太初
    YAOCHI = 4,     --瑶池
    QINGSHAN = 5,   --青山
    YAOSHEN = 6,    --妖神
}

ASSISTANT_SCHOOL = {
    [PLAYER_SCHOOL.JINSHAN] = 1,
    [PLAYER_SCHOOL.YAOCHI] = 1,
    [PLAYER_SCHOOL.QINGSHAN] = 1,
}

SCHOOL_NPC = {
    5259,    --蜀山
    5263,    --金山
    5260,    --太初
    5262,     --瑶池
    5258,   --青山
    5261,    --妖神
}

SCHOOL_TITLE = {
    920,    --蜀山
    921,    --金山
    922,    --太初
    923,     --瑶池
    924,   --青山
    925,    --妖神
}

SCENE_ENTITY_TYPE = {
    ENTITY_TYPE = 0,
    PLAYER_TYPE = 1,
    NPC_TYPE = 2,
    EFFECT_TYPE = 3, -- 特效
    TEAM_TYPE = 4,
}

-- 前端战斗用
GAME_SYS_TYPE = {
    SYS_TYPE_NONE = 0,                      -- 
    SYS_TYPE_GHOST = 1,                     -- 抓鬼
    SYS_TYPE_SHIMEN = 2,                    -- 师门
    SYS_TYPE_STORY = 3,                     -- 主线
    SYS_TYPE_JJC = 4,                       -- 竞技场单人
    SYS_TYPE_CHALLENGE = 5,                 -- 竞技场连续挑战 
    SYS_TYPE_ARENA = 6,                     -- 暗雷
    SYS_TYPE_BIWU = 7,                      -- 比武
    SYS_TYPE_LIUMAI = 8,                    -- 六脉
    SYS_TYPE_MENGZHU = 9,                   -- 盟主
    SYS_TYPE_TRAPMINE = 10,                 -- 
    SYS_TYPE_FENGYAO = 11,                  -- 封妖
    SYS_TYPE_DEVIL = 12,                    -- 天魔
    SYS_TYPE_SCHOOLPASS = 13,               -- 门派试炼
    SYS_TYPE_ORGWAR = 14,                   -- 帮战
    SYS_TYPE_TRIAL = 15,                    -- 试炼
    SYS_TYPE_RUNRING = 16,                  -- 跑环
    SYS_TYPE_NIANSHOU = 17,                 -- 年兽
    SYS_TYPE_SINGLEWAR = 18,                -- 蜀山论道
    SYS_TYPE_TREASURECONVOY = 19,           -- 秘宝押送
}

WAR_TYPE = {
    PVE_TYPE = 1,
    PVP_TYPE = 2,
    WAR_VIDEO_TYPE = 3,
}

WAR_WARRIOR_TYPE = {
    WARRIOR_TYPE = 0,
    PLAYER_TYPE = 1,
    NPC_TYPE = 2,
    SUMMON_TYPE = 3,
    PARTNER_TYPE = 4,
    ROPLAYER_TYPE = 5,
    ROPARTNER_TYPE = 6,
    ROSUMMON_TYPE = 7,
}

WAR_WARRIOR_STATUS = {
    NULL = 0,
    ALIVE = 1,
    DEAD = 2,
}

WAR_WARRIOR_SIDE = {
    FRIEND = 1,
    ENEMY = 2,
    WITNESS = 3,
}

WAR_BOUT_STATUS = {
    NULL = 0,
    OPERATE = 1,
    ANIMATION = 2,
}

WAR_RECV_DAMAGE_FLAG = {
    NULL = 0,
    MISS = 1,
    DEFENSE = 2,
    CRIT = 3,
    IMMUNE = 4,
}

WAR_PERFORM_TYPE = {
    PHY = 1,
    MAGIC = 2,
}

WAR_ACTION_TYPE = {
    ATTACK = 1,
    SEAL = 2,
    FUZHU = 3,
    CURE = 4,
}

WAR_AUTO_TYPE = {
    FORBID_AUTO = 0,
    START_AUTO = 1,
    USE_LAST = 2,
}

-- 任务功能类型(tasktype项)
TASK_TYPE = {
    TASK_FIND_NPC    = 1,
    TASK_FIND_ITEM   = 2,
    TASK_FIND_SUMMON = 3,
    TASK_NPC_FIGHT   = 4,
    TASK_ANLEI       = 5,
    TASK_PICK        = 6,
    TASK_USE_ITEM    = 7,
    TASK_UPGRADE     = 8,
    TASK_CAPTURE     = 9,
    TASK_QTE         = 10,
    TASK_SAY         = 11,
    TASK_BEHAVIOR    = 12,
    -- TASK_CONDITION = 99, -- 考虑作为UPGRADE类型的泛型，做一切条件检查的任务
}

TEAM_MEMBER_STATUS = {
    MEMBER = 1,
    SHORTLEAVE = 2,
    OFFLINE = 3,
}

TEAM_CB_TYPE = {
    LEAVE_WAR = 1,
}

TEAM_CB_FLAG = {
    LEAVE = "leave",
    SHORTLEAVE = "shortleave",
    BACK = "back",
    SETLEADER = "setleader",
    KICKOUT = "kickout"
}

INTERFACE_TYPE = {
    BASE_TYPE = 0,
    ORG_RESPOND_TYPE = 1,
    BAIKE_MAINUI_TYPE = 2,
    JJC_MAINUI_TYPE = 3,
    GOLDCOIN_PARTY = 4,
}

BROADCAST_TYPE = {
    BASE_TYPE = 0,
    WORLD_TYPE = 1,
    TEAM_TYPE = 2,
    FRIEND_FOCUS_TYPE = 3,
    ORG_TYPE = 4,
    INTERFACE_TYPE = 5,
    PUB_TEAM_TYPE = 6,
}

CHANNEL_TYPE = {
    BASE_TYPE = 0,
    WORLD_TYPE = 1,
    TEAM_TYPE = 2,
    ORG_TYPE = 3,
    CURRENT_TYPE = 4,
    SYS_TYPE = 5,
    MSG_TYPE = 6,
}

SYS_CHANNEL_TAG = {
    NOTICE_TAG = 0,             -- 系统
    RUMOUR_TAG = 1,          -- 传闻
    HELP_TAG = 2,                 -- 帮助  
}

AI_TYPE = {
    COMMON = 101,
    DEFENSE = 102,
    AUTOPERFORM = 103,
    SUMMON_AI = 301,
    NPC_AI = 401,
}

AI_ACTION = {
    TYPE = {
        SINGLE_ATTACK = 101,        --单体攻击
        GROUP_ATTACK = 201,         --群体攻击
        SINGLE_SEAL = 102,          --单体封印
        GROUP_SEAL = 202,           --群体封印
        SINGLE_CURE = 104,          --单体治疗
        GROUP_CURE = 204,           --群体治疗
        SINGLE_UNSEAL = 105,        --单体解封
        GROUP_UNSEAL = 205,         --群体解封
        SINGLE_GOOD = 106,          --单体增益
        GROUP_GOOD = 206,           --群体增益
        SINGLE_REVIVE = 107,        --单体复活
        GROUP_REVIVE = 207,         --群体复活
        SINGLE_BAD = 108,           --单体减益
        GROUP_BAD = 208,            --群体减益
        SUMMON = 109,               --召唤
        CHANGE_SHAPE = 110,         --变身
    },
    CLASS = {
        ATTACK = 1,                 --攻击
        SEAL = 2,                   --封印
        CURE = 4,                   --治疗
        UNSEAL = 5,                 --解封
        BENIFIT = 6,                --增益
        REVIVE = 7,                 --复活
        HARMFUL = 8,                --减益
        SUMMON = 9,                 --召唤
        CHANGE_SHAPE = 10,          --变身
    },
}

BUFF_TYPE = {
    CLASS_BENEFIT = 1,
    CLASS_ABNORMAL = 2,
    CLASS_TEMP = 3,
    CLASS_SPECIAL = 4,
}

ACTIVITY_STATE = {
    STATE_READY = 1,
    STATE_START = 2,
    STATE_END = 3,
    STATE_HIDE = 4
}

TEXT_TYPE = {
    SECOND_CONFIRM = 1001,
    WINDOW_TIPS = 1003,
}

SEX_TYPE = {
    SEX_MALE = 1,
    SEX_FEMALE = 2,
}

PARTNER_EQUIP_POS = {
    EQUIP_WEAPON = 1,
    EQUIP_PROTECT = 2,
}

NPC_TYPE = {
    SHOP = 5002,
}

-- NPC所属玩法系统，须各不相同，且与前端定义一致
NPC_FUNC_GROUP = {
    ["task"] = {
        ["test"] = 1,
        ["story"] = 2,
        ["side"] = 3,
        ["shimen"] = 4,
        ["ghost"] = 5,
        ["yibao"] = 6,
        ["fuben"] = 7,
        ["schoolpass"] = 8,
        ["orgtask"] = 9,
        ["lingxi"] = 10,
    },
    ["huodong"] = {
        ["fengyao"] = 1001,
        ["trapmine"] = 1002,
        ["normal"] = 1003,
        ["excellent"] = 1004,
        ["treasure"] = 1005,
        ["devil"] = 1006,
        ["arena"] = 1007,
        ["shootcraps"] = 1008,
        ["dance"] = 1009,
        ["signin"] = 1010,
        ["orgcampfire"] = 1011,
        ["mengzhu"] = 1012,
        ["biwu"] = 1013,
        ["schoolpass"] = 1014,
        ["moneytree"] = 1015,
        ["orgtask"] = 1016,
        ["charge"] = 1017,
        ["bottle"] = 1018,
        ["baike"] = 1019,
        ["liumai"] = 1020,
        ["lingxi"] = 1021,
    },
}

ROLE_MODEL = {
    PLAYER_MIRROR = -1, -- 复制玩家的造型
}

SPEED_MOVE = 3

-- 变身构建优先级列
BIANSHEN_PRIORITY = {
    TOP = 100,
    HIGH = 90,
    DEFAULT = 50, -- 默认范围给比较大，可以随意插入中间定义
    LOW = 10,
    BOTTOM = 1,
}

BIANSHEN_GROUP = {
    TASK = "task", -- 任务
    CARD = "card", -- 变身卡
    HUODONG_HFDM = "hfdm", -- 活动画舫灯谜
}

MONEY_TYPE = {
    GOLD    = 1,    --金币
    SILVER  = 2,    --银币
    GOLDCOIN= 3,    --元宝
    RPLGOLD = 4,    --代金
    ORGOFFER = 5,   --帮贡
    WUXUN = 6,      --武勋
    JJCPOINT = 7,   --竞技场积分
    LEADERPOINT = 8,--功勋值
    XIAYIPOINT = 9, --侠义值
    SUMMONPOINT = 10, --宠物合成积分
    STORYPOINT = 11, --剧情技能点
    TRUE_GOLDCOIN= 12,    --非绑定元宝
    CHUMOPOINT = 13,    --除魔值
}

MONEY_NAME = {
    [1]   = "金币",
    [2]   = "银币",
    [3]   = "元宝",
    [4]   = "代金",
    [5]   = "帮贡",
    [6]   = "武勋",
    [7]   = "竞技场积分",
    [8]   = "功勋值",
    [9]   = "侠义值",
    [10]  = "宠物合成积分",
    [11]  = "剧情技能点",
    [12]  = "非绑定元宝",
    [13]  = "除魔值",
}

-- 
MONEY_VIRTUAL_ITEM = {
    GOLD = 1001,  -- 金币
    SILVER  = 1002,    --银币
    GOLDCOIN= 1003,    --元宝--绑定优先然后非绑定-- 没有非绑定元宝
    RPLGOLD = 1004,    --代金-- 绑定元宝
    ORGOFFER = 1008,   --帮贡
    WUXUN = 1013,      --武勋
    JJCPOINT = 1014,   --竞技场积分
    LEADERPOINT = 1021,--队长积分
    XIAYIPOINT = 1022, --侠义值
    SUMMONPOINT = 1025, --宠物合成积分
    STORYPOINT = 1024, --剧情技能点  
    CHUMOPOINT = 1027,  --除魔值
}

JJC_TARGET_TYPE = {
    PLAYER = 1,
    ROBOT = 2,
}

JJC_FIGHTER_TYPE = {
    PLAYER = 1,
    PARTNER = 2,
}

JJC_MATCH_GROUP = {
    LEVEL1 = 1,     -- 青铜
    LEVEL2 = 2,     -- 白银
    LEVEL3 = 3,     -- 黄金
}

SIGNIN_FORTUNE = {
    YYJH = 1001,    -- 阴阳交汇
    FXGZ = 1002,    -- 福星高照
    CYHT = 1003,    -- 财运亨通
    --SHJD = 1004,    -- 三花聚顶
    BGYX = 1005,    -- 百鬼夜行
    CSD = 1006,    -- 财神到
}

EVENT = {
    ON_LOGIN = 1001,                     -- 登录
    PLAYER_ENTER_SCENE = 1002,           -- 进场
    PLAYER_REENTER_SCENE = 1003,         -- 重进场
    PLAYER_LEAVE_SCENE = 1004,           -- 离场
    ON_UPGRADE = 1011,                   -- 升级.
    PLAYER_ENTER_WAR_SCENE = 1101,       -- 玩家进入战斗场景（包含观战）
    TEAM_CREATE = 1501,                  -- 创建队
    TEAM_ADD_MEMBER = 1502,              -- 入队
    TEAM_ADD_SHORT_LEAVE = 1503,         -- 暂离式入队
    TEAM_LEAVE = 1504,                  --离队
    TEAM_SHORTLEAVE = 1505,                  --暂离
    TEAM_OFFLINE = 1506,                  --下线
    TEAM_BACKTEAM = 1507,                  --下线
    CREATE_ORG = 2001,                   -- 建帮
    LEAVE_ORG = 2002,                    -- 离帮
    JOIN_ORG = 2003,                     -- 进帮
    SHIMEN_DONE = 2101,                  -- 完成师门任务
    GHOST_DONE = 2102,                   -- 完成抓鬼任务
    YIBAO_DONE_SUB = 2103,               -- 完成一个异宝子任务
    FENGYAO_DONE = 2104,                 -- 完成封妖
    FUBEN_DONE = 2151,                   -- 完成副本
    SCHEDULE_DONE = 2161,                -- 完成一次日程
    JJC_FIGHT_END = 2201,                -- 完成一场竞技场
    TRIAL_FIGHT_START = 2211,            -- 英雄试炼战斗一场
    EQUIP_STRENGTHEN = 2251,             -- 装备强化
    EQUIP_WASH = 2252,                   -- 装备洗练
    EQUIP_DAZAO = 2253,                  -- 装备洗练
    EQUIP_FUHUN = 2254,                  -- 装备附魂
    PARTNER_USE_UPGRADE_PROP = 2261,     -- 伙伴用升级物品
    PARTNER_SKILL_UPGRADE = 2262,        -- 伙伴升级技能
    PARTNER_INCREASE_UPPER = 2263,       -- 伙伴突破
    PARTNER_INCREASE_QUALITY = 2264,     -- 伙伴进阶
    SUMMON_USE_EXP_BOOK = 2271,          -- 宠物使用经验丹
    SUMMON_SKILL_LEVELUP = 2272,         -- 宠物技能升级
    SUMMON_STICK_SKILL = 2273,           -- 宠物学习技能
    SUMMON_COMBINE = 2274,               -- 宠物合成
    SUMMON_WASH = 2275,                  -- 宠物洗练（重生）
    SUMMON_CULTIVATE_APTITUDE = 2276,    -- 宠物培养
    PLAYER_LEARN_ACTIVE_SKILL = 2281,    -- 主角学习招式技能
    PLAYER_LEARN_PASSIVE_SKILL = 2282,   -- 主角学习心法技能
    PLAYER_LEARN_CULTIVATE_SKILL = 2283, -- 主角学习修炼技能
    PLAYER_LEARN_ORG_SKILL = 2284,       -- 主角学习帮派技能
    PLAYER_TOUXIAN_UPGRADE = 2291,       -- 主角晋升头衔
    PLAYER_RESUME_TRUEGOLDCOIN = 2301,   -- 玩家消费非绑定元宝
    SYS_OPEN_STATUS_CHANGE = 2302,       -- 后台系统开放状态变化  
    WORLD_SERVER_START_END = 2303,       -- 服务器启动完成 

    WAR_START = 31001,                     -- war服战斗开始
    WAR_BOUT_START = 31002,                -- war服回合开始
    WAR_NEW_BOUT = 31003,                  -- war服回合指令执行开始(指令收集完毕)
    WAR_BOUT_END = 31004,                  -- war服回合结束
    WAR_BEFORE_ACT = 31005,                -- war服角色指令执行前
    WAR_MONSTER_HP_SUB_TO_PERCENT = 31006, -- war服怪物血量降至x%
    WAR_ESCAPE = 31007,                    -- war服逃跑
    WAR_BOUT_PRE_START = 31008,            -- war服回合开始前
}

SCHEDULE_TYPE = {
    DAILY = 1,
    FUBEN = 2,
    TIMED = 3,
    WEEKLY = 4,
}

WAR_STATUS = {
    IN_WAR = 1,         --参加战斗
    IN_OBSERVER = 2,    --观看战斗
    NO_WAR = 3,         --无战斗状态
}

REWARD_ITEM_SIDTYPE = {
    DEFAULT = 0, -- 正常物品sid
    FILTER = 1,  -- 筛选表id
}

RANSE_TYPE = {
    HAIR = 1,   --头发
    CLOTHES = 2, -- 外观
    SUMMON = 3, -- 宠物
    SHIZHUANG  = 4, -- 时装
    PANT = 5,--裤子
}

FIND_PATH_FUNC_TYPE = {
    TREASURE = 1, -- 宝图罗盘
    TASKSAY = 2, -- 喊话任务
}

ENTITY_ACTION_TYPE = {
    WATER_WALK = 1, -- 踩水
}

CHANNEL_SYS_SWITCH = {
    FEEDBACK = 1,   -- 客服反馈
    FEEDBACKINFO = 2, -- 客服公告 
}

TODAY_PAY_GOLDCOIN = "today_pay_goldcoin"

function CoverPos(mPos)
    return {
        v = mPos.v and geometry.Cover(mPos.v),
        x = mPos.x and geometry.Cover(mPos.x),
        y = mPos.y and geometry.Cover(mPos.y),
        z = mPos.z and geometry.Cover(mPos.z),
        face_x = mPos.face_x and geometry.Cover(mPos.face_x),
        face_y = mPos.face_y and geometry.Cover(mPos.face_y),
        face_z = mPos.face_z and geometry.Cover(mPos.face_z),
    }
end

function RecoverPos(mPos)
    return {
        v = mPos.v and geometry.Recover(mPos.v),
        x = mPos.x and geometry.Recover(mPos.x),
        y = mPos.y and geometry.Recover(mPos.y),
        z = mPos.z and geometry.Recover(mPos.z),
        face_x = mPos.face_x and geometry.Recover(mPos.face_x),
        face_y = mPos.face_y and geometry.Recover(mPos.face_y),
        face_z = mPos.face_z and geometry.Recover(mPos.face_z),
    }
end

-- 操作类型
VERSION_OP_TYPE = {
    ADD = 1,
    UPDATE = 2, 
    DELETE = 3,
}

SECOND_PROP_MAP = {
    speed = "speed_unit",
    mag_defense = "mag_defense_unit",
    phy_defense = "phy_defense_unit",
    mag_attack = "mag_attack_unit",
    phy_attack = "phy_attack_unit",
    max_hp = "max_hp_unit",
    max_mp = "max_mp_unit",
}

WALK_SPEED = 2.8
HALF_SCREEN = 13000
CHECK_SCREEN = HALF_SCREEN * 4

-- 不扣死亡装备耐久 
NOT_SUB_DEAD_LAST = {
    liumai      = 1,
    orgwar      = 1,
    moneytree   = 1,
    schoolpass  = 1,
    biwu        = 1,
    mengzhu     = 1,
    jjc         = 1,
    trial       = 1,
    arena       = 1,
    threebiwu   = 1,
    orgwar      = 1,
    singlewar    = 1,
    treasureconvoy = 1,
}

BAOSHI_GAMEPLAY ={
    arena = true,
    biwu = true,
    threebiwu = true,
    liumai = true,
    singlewar = true,
    treasureconvoy = true,
}

PARTNER_AI_NORMAL = {
    fengyao = 1,
    ghost = 1,
    shimen = 1,
    story = 1,
    baotu = 1,
    side = 1,
}


-- 1、打造 2、强化 3、洗炼 4、附魂
UI_EFFECT_MAP = {
    NONE = 0,
    DAO_ZAO = 1,
    QIANG_HUA = 2,
    XI_LIAN = 3,
    FU_HUN = 4,
}

WAR_SPECIAL_NPC={
    ["nianshou"] = 1,--年兽 
}

-- 道具便捷购买 价格来源
STORE_TYPE = {
    GUILD = 1,  -- 商会
    NPCSTORE = 2, -- 元宝商城 301 商店
    COMP = 3, -- 商会 和 元宝商城 301 商店 二者更便宜者
    STALL = 4, -- 摆摊，摆摊目前全部为银币价格
}

-- KS 玩家心跳间隔(S)
KS_PLAYER_HT_INTERVAL = 10

-- 经验找回天
RETRIEVE_EXP_DAY = 2
