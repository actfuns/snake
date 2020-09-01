-- ./excel/system/chat/chatconfig.xlsx
return {

    [1] = {
        define = 1,
        energy_cost = "math.max(1,40-math.floor(lv/10)*5)",
        grade_limit = "20",
        id = 1,
        name = "世界",
        sort = 2,
        talk_gap = "math.max(40,170-lv*2)",
        talkable = 1,
        voiceable = 1,
    },

    [2] = {
        define = 2,
        energy_cost = "0",
        grade_limit = "0",
        id = 2,
        name = "队伍",
        sort = 5,
        talk_gap = "2",
        talkable = 1,
        voiceable = 1,
    },

    [3] = {
        define = 3,
        energy_cost = "0",
        grade_limit = "0",
        id = 3,
        name = "帮派",
        sort = 4,
        talk_gap = "2",
        talkable = 1,
        voiceable = 1,
    },

    [4] = {
        define = 4,
        energy_cost = "0",
        grade_limit = "0",
        id = 4,
        name = "当前",
        sort = 3,
        talk_gap = "2",
        talkable = 1,
        voiceable = 1,
    },

    [5] = {
        define = 100,
        energy_cost = "0",
        grade_limit = "0",
        id = 5,
        name = "系统",
        sort = 1,
        talk_gap = "1",
        talkable = 0,
        voiceable = 1,
    },

    [6] = {
        define = 6,
        energy_cost = "0",
        grade_limit = "0",
        id = 6,
        name = "消息",
        sort = 6,
        talk_gap = "0",
        talkable = 0,
        voiceable = 0,
    },

}
