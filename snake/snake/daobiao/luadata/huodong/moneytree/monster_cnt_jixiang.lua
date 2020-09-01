-- ./excel/huodong/moneytree/condition.xlsx
return {

    [1] = {
        monster_idx = 20011,
        monster_radio = 1000,
        ratio = {{["amount"] = 3, ["ratio"] = "20"}, {["amount"] = 4, ["ratio"] = "30"}, {["amount"] = 5, ["ratio"] = "50"}},
    },

    [2] = {
        monster_idx = 20012,
        monster_radio = 1000,
        ratio = {{["amount"] = 1, ["ratio"] = "50"}},
    },

    [3] = {
        monster_idx = 20013,
        monster_radio = 1500,
        ratio = {{["amount"] = 1, ["ratio"] = "30"}},
    },

    [4] = {
        monster_idx = 20014,
        monster_radio = 1500,
        ratio = {{["amount"] = 1, ["ratio"] = "40"}, {["amount"] = 2, ["ratio"] = "1"}},
    },

    [5] = {
        monster_idx = 20015,
        monster_radio = 1000,
        ratio = {{["amount"] = 1, ["ratio"] = "40"}, {["amount"] = 2, ["ratio"] = "1"}},
    },

    [6] = {
        monster_idx = 20016,
        monster_radio = 1000,
        ratio = {{["amount"] = 1, ["ratio"] = "40"}, {["amount"] = 2, ["ratio"] = "10"}},
    },

    [7] = {
        monster_idx = 20017,
        monster_radio = 1000,
        ratio = {{["amount"] = 1, ["ratio"] = "60"}, {["amount"] = 2, ["ratio"] = "math.floor(1+newbie*10)"}, {["amount"] = 3, ["ratio"] = "math.floor(0+newbie*10)"}},
    },

    [8] = {
        monster_idx = 20018,
        monster_radio = 2000,
        ratio = {{["amount"] = 1, ["ratio"] = "60"}, {["amount"] = 2, ["ratio"] = "1"}, {["amount"] = 3, ["ratio"] = "0"}},
    },

}
