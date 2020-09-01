-- ./excel/huodong/returngoldcoin/config.xlsx
return {

    [1] = {
        first_reward = {["grade"] = 10, ["reward"] = "all"},
        id = 1,
        money_range = {["max"] = 100, ["min"] = 0},
        second_reward = {["grade"] = 0, ["reward"] = "0"},
        third_reward = {["grade"] = 0, ["reward"] = "0"},
    },

    [2] = {
        first_reward = {["grade"] = 10, ["reward"] = "goldcoin"},
        id = 2,
        money_range = {["max"] = 500, ["min"] = 100},
        second_reward = {["grade"] = 35, ["reward"] = "rplgoldcoin"},
        third_reward = {["grade"] = 0, ["reward"] = "0"},
    },

    [3] = {
        first_reward = {["grade"] = 10, ["reward"] = "goldcoin"},
        id = 3,
        money_range = {["max"] = 999999999, ["min"] = 500},
        second_reward = {["grade"] = 35, ["reward"] = "half_rplgoldcoin"},
        third_reward = {["grade"] = 45, ["reward"] = "half_rplgoldcoin"},
    },

}
