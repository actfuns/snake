-- ./excel/system/ai/config.xlsx
return {

    [1] = {
        args = "",
        func = "Default",
        id = 1,
        name = "默认",
    },

    [2] = {
        args = "",
        func = "Random",
        id = 2,
        name = "随机目标",
    },

    [3] = {
        args = "",
        func = "HpMin",
        id = 3,
        name = "血量少优先",
    },

    [4] = {
        args = "",
        func = "HpMax",
        id = 4,
        name = "血量多优先",
    },

    [5] = {
        args = "",
        func = "MagDefenseMin",
        id = 5,
        name = "法防低优先",
    },

    [6] = {
        args = "{ratio=50}",
        func = "HpLess",
        id = 6,
        name = "血量少50",
    },

    [7] = {
        args = "",
        func = "BeSealed",
        id = 7,
        name = "被封印",
    },

    [8] = {
        args = "{ratio=100,all=true}",
        func = "HpMore",
        id = 8,
        name = "全部满血",
    },

    [9] = {
        args = "{changed=154}",
        func = "UnChangeShape",
        id = 9,
        name = "未变身154",
    },

    [10] = {
        args = "{changed=155}",
        func = "UnChangeShape",
        id = 10,
        name = "未变身155",
    },

    [11] = {
        args = "{changed=115}",
        func = "UnChangeShape",
        id = 11,
        name = "未变身115",
    },

    [12] = {
        args = "{limit=3}",
        func = "TargetMore",
        id = 12,
        name = "目标人数大于等于3",
    },

    [13] = {
        args = "{limit=2}",
        func = "TargetMore",
        id = 13,
        name = "目标人数大于等于2",
    },

    [14] = {
        args = "{limit=1}",
        func = "TargetLess",
        id = 14,
        name = "目标人数小于等于1",
    },

    [15] = {
        args = "{hp=50,limit=1}",
        func = "Target7302",
        id = 15,
        name = "狂剑",
    },

    [16] = {
        args = "{hp=50,limit=2,school=3,buff=197}",
        func = "Target7303",
        id = 16,
        name = "瞬斩",
    },

    [17] = {
        args = "{hp=50}",
        func = "Target8302",
        id = 17,
        name = "狂剑1",
    },

    [18] = {
        args = "{school={2,3,4,5}}",
        func = "Target7502",
        id = 18,
        name = "封灵",
    },

    [19] = {
        args = "{school={1,6}}",
        func = "Target7503",
        id = 19,
        name = "迷魂",
    },

    [20] = {
        args = "{school=5}",
        func = "Target7602",
        id = 20,
        name = "封灵1",
    },

    [21] = {
        args = "{limit=2}",
        func = "Target7603",
        id = 21,
        name = "封神",
    },

    [22] = {
        args = "",
        func = "Revive",
        id = 22,
        name = "轮回",
    },

    [23] = {
        args = "{buff_list={199,123,161}}",
        func = "Target7902",
        id = 23,
        name = "蜃气",
    },

    [24] = {
        args = "{school={2,4}}",
        func = "Target8003",
        id = 24,
        name = "清心",
    },

    [25] = {
        args = "{school={1,3,6}}",
        func = "SchoolSeq",
        id = 25,
        name = "杀破狼",
    },

    [26] = {
        args = "{school={2,4}}",
        func = "PosFirst",
        id = 26,
        name = "隔山打牛",
    },

    [27] = {
        args = "{ratio=95}",
        func = "FriendHpMore",
        id = 27,
        name = "所有队员血量大于95",
    },

    [28] = {
        args = "",
        func = "UnSealed",
        id = 28,
        name = "未被封印",
    },

    [29] = {
        args = "{buff=114}",
        func = "NoBuff",
        id = 29,
        name = "无状态114优先",
    },

    [30] = {
        args = "{buff=116,maxhp=true}",
        func = "NoBuff",
        id = 30,
        name = "无状态116气血多优先",
    },

    [31] = {
        args = "{buff=119,maxhp=true}",
        func = "NoBuff",
        id = 31,
        name = "无状态119气血多优先",
    },

    [32] = {
        args = "{buff=121}",
        func = "NoBuff",
        id = 32,
        name = "无状态121优先",
    },

    [33] = {
        args = "",
        func = "SpeedMax",
        id = 33,
        name = "速度快优先",
    },

}
