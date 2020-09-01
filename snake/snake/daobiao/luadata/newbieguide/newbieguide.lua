-- ./excel/newbieguide/newbieguide.xlsx
return {

    [1000] = {
        desc = "点击主线任务追踪",
        id = 1000,
        next = 0,
        trigger = "首次进入游戏",
    },

    [1001] = {
        desc = "引导点击对话框",
        id = 1001,
        next = 0,
        trigger = "主线10101弹出NPC对话",
    },

    [1002] = {
        desc = "引导点击包裹按钮",
        id = 1002,
        next = 1003,
        trigger = "主线10101任务完成",
    },

    [1003] = {
        desc = "点击武器  ",
        id = 1003,
        next = 1004,
        trigger = "",
    },

    [1004] = {
        desc = "点击装备按钮",
        id = 1004,
        next = 1005,
        trigger = "",
    },

    [1005] = {
        desc = "点击关闭",
        id = 1005,
        next = 1006,
        trigger = "",
    },

    [1006] = {
        desc = "点击主线任务追踪",
        id = 1006,
        next = 0,
        trigger = "",
    },

    [1007] = {
        desc = "点击进入战斗",
        id = 1007,
        next = 1008,
        trigger = "主线10251任务NPC太阴真人对话结束",
    },

    [1008] = {
        desc = "战斗中，引导点击攻击按钮",
        id = 1008,
        next = 1009,
        trigger = "",
    },

    [1009] = {
        desc = "再点击选择太阴真人为攻击目标",
        id = 1009,
        next = 1010,
        trigger = "",
    },

    [1010] = {
        desc = "再引导点击技能按钮",
        id = 1010,
        next = 1011,
        trigger = "",
    },

    [1011] = {
        desc = "选择第一个技能",
        id = 1011,
        next = 1012,
        trigger = "",
    },

    [1012] = {
        desc = "再点击选择太阴真人为攻击目标",
        id = 1012,
        next = 1013,
        trigger = "",
    },

    [1013] = {
        desc = "再引导点击自动按钮",
        id = 1013,
        next = 0,
        trigger = "",
    },

    [1014] = {
        desc = "点击商城按钮",
        id = 1014,
        next = 1015,
        trigger = "接取主线10351任务",
    },

    [1015] = {
        desc = "进入商城，点击宠物商店标签",
        id = 1015,
        next = 1016,
        trigger = "",
    },

    [1016] = {
        desc = "点击野猪",
        id = 1016,
        next = 1017,
        trigger = "",
    },

    [1017] = {
        desc = "点击购买",
        id = 1017,
        next = 1018,
        trigger = "",
    },

    [1018] = {
        desc = "点击关闭",
        id = 1018,
        next = 1019,
        trigger = "",
    },

    [1019] = {
        desc = "点击宠物头像",
        id = 1019,
        next = 1020,
        trigger = "",
    },

    [1020] = {
        desc = "点击参战",
        id = 1020,
        next = 1021,
        trigger = "",
    },

    [1021] = {
        desc = "点击关闭",
        id = 1021,
        next = 1022,
        trigger = "",
    },

    [1022] = {
        desc = "点击主线任务追踪",
        id = 1022,
        next = 0,
        trigger = "",
    },

    [1023] = {
        desc = "引导点击帮派",
        id = 1023,
        next = 1024,
        trigger = "主线10303任务完成",
    },

    [1024] = {
        desc = "点击一键申请",
        id = 1024,
        next = 1025,
        trigger = "",
    },

    [1025] = {
        desc = "点击关闭",
        id = 1025,
        next = 0,
        trigger = "",
    },

    [1026] = {
        desc = "点击师门任务追踪",
        id = 1026,
        next = 0,
        trigger = "首次接取师门任务",
    },

}
