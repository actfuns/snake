-- import module
-- 废弃模块，不要再用

local PLATFORM = import(lualib_path("public.gamedefines")).PLATFORM
local PUBLISHER = import(lualib_path("public.gamedefines")).PUBLISHER

SERVER_DESC = {
    all = 0,
    czk_android = 1,
    czk_ios = 2,
    czk_pioneer = 3,
    czk_tail = 4,
    czk_tailmix = 5,
    czk_mix = 6,
    sm_mix = 7,
    sm_android = 8,
    sm_ios = 9,
}

SERVER_DESC_NAME = {
    [SERVER_DESC.all] = "全类型服",
    [SERVER_DESC.czk_mix] = "混服-晨之科",       --不包含长尾
    [SERVER_DESC.czk_android] = "安卓-晨之科",   --不包含长尾
    [SERVER_DESC.czk_ios] = "IOS-晨之科",          --不包含长尾
    [SERVER_DESC.czk_pioneer] = "官方测试服-晨之科",
    [SERVER_DESC.czk_tail] = "长尾专服-晨之科",
    [SERVER_DESC.czk_tailmix] = "长尾混服-晨之科",
    [SERVER_DESC.sm_mix] = "混服-手盟",
    [SERVER_DESC.sm_android] = "安卓-手盟",
    [SERVER_DESC.sm_ios] = "IOS-手盟",
}

PUBLISHER_MATCH = {
    [SERVER_DESC.all] = PUBLISHER.none,
    [SERVER_DESC.czk_mix] = PUBLISHER.czk,
    [SERVER_DESC.czk_android] = PUBLISHER.czk,   --不包含长尾
    [SERVER_DESC.czk_ios] = PUBLISHER.czk,          --不包含长尾
    [SERVER_DESC.czk_pioneer] = PUBLISHER.czk,
    [SERVER_DESC.czk_tail] = PUBLISHER.czk,
    [SERVER_DESC.czk_tailmix] = PUBLISHER.czk,
    [SERVER_DESC.sm_mix] = PUBLISHER.sm,
    [SERVER_DESC.sm_android] = PUBLISHER.sm,
    [SERVER_DESC.sm_ios] = PUBLISHER.sm,
}

PLATFORM_MATCH = {
    [SERVER_DESC.all] = {PLATFORM.android, PLATFORM.rootios, PLATFORM.ios, PLATFORM.pc},
    [SERVER_DESC.czk_mix] = {PLATFORM.android, PLATFORM.rootios, PLATFORM.ios, PLATFORM.pc},
    [SERVER_DESC.czk_android] = {PLATFORM.android, PLATFORM.pc},
    [SERVER_DESC.czk_ios] = {PLATFORM.rootios, PLATFORM.ios, PLATFORM.pc},
    [SERVER_DESC.czk_pioneer] = {PLATFORM.android, PLATFORM.pc},
    [SERVER_DESC.czk_tail] = {PLATFORM.android, PLATFORM.pc},
    [SERVER_DESC.czk_tailmix] = {PLATFORM.android, PLATFORM.pc},
    [SERVER_DESC.sm_mix] = {PLATFORM.android, PLATFORM.rootios, PLATFORM.ios, PLATFORM.pc},
    [SERVER_DESC.sm_android] = {PLATFORM.android, PLATFORM.pc},
    [SERVER_DESC.sm_ios] = {PLATFORM.rootios, PLATFORM.ios, PLATFORM.pc},
}

CHANNEL_MATCH = {
    [SERVER_DESC.all] = "all",
    [SERVER_DESC.czk_mix] = "czk_mix",
    [SERVER_DESC.czk_android] = "czk_android",
    [SERVER_DESC.czk_ios] = "czk_ios",
    [SERVER_DESC.czk_pioneer] = {1045}, -- 咕噜
    [SERVER_DESC.czk_tail] = "czk_tail",    -- 云霄
    [SERVER_DESC.czk_tailmix] = {"czk_tail", 1002, 1010}, -- 云霄，uc，360
    [SERVER_DESC.sm_mix] = "sm_mix",
    [SERVER_DESC.sm_android] = "sm_android",
    [SERVER_DESC.sm_ios] = "sm_ios",
}

CPS_CHANNEL_MATCH = {
    [SERVER_DESC.all] = "all",
    [SERVER_DESC.czk_mix] = {"-CPS_300020", "-CPS_300021"},
    [SERVER_DESC.czk_android] = {"-CPS_300020", "-CPS_300021"},
    [SERVER_DESC.czk_ios] = {"-CPS_300020", "-CPS_300021"},
    [SERVER_DESC.czk_pioneer] = {"CPS_300020", "CPS_300021", "a0001"},
    [SERVER_DESC.czk_tail] = {"-CPS_300020", "-CPS_300021"},
    [SERVER_DESC.czk_tailmix] = {"-CPS_300020", "-CPS_300021"},
    [SERVER_DESC.sm_mix] = "all",
    [SERVER_DESC.sm_android] = "all",
    [SERVER_DESC.sm_ios] = "all",
}

