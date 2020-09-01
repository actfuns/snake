-- ./excel/system/dazao/shenhun.xlsx
return {

    [1] = {
        attr = "phy_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1.5)", ["weight"] = 50}, {["ratio"] = "rf(2,2.5)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 1,
    },

    [2] = {
        attr = "seal_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 1,
    },

    [3] = {
        attr = "phy_attack",
        attr_ratio = {{["ratio"] = "math.random(ilv/10+20,ilv/10+30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 1,
    },

    [4] = {
        attr = "mag_attack",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 1,
    },

    [5] = {
        attr = "cure_power",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 1,
    },

    [6] = {
        attr = "mag_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 1,
    },

    [7] = {
        attr = "res_phy_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 2,
    },

    [8] = {
        attr = "res_mag_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 2,
    },

    [9] = {
        attr = "phy_defense",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 2,
    },

    [10] = {
        attr = "max_mp",
        attr_ratio = {{["ratio"] = "math.random(40,50)", ["weight"] = 30}, {["ratio"] = "math.random(50,60)", ["weight"] = 10}},
        pos = 2,
    },

    [11] = {
        attr = "res_phy_defense_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1.5)", ["weight"] = 50}, {["ratio"] = "rf(2,2.5)", ["weight"] = 30}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 3,
    },

    [12] = {
        attr = "res_mag_defense_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1.5)", ["weight"] = 50}, {["ratio"] = "rf(2,2.5)", ["weight"] = 30}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 3,
    },

    [13] = {
        attr = "res_phy_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1.5)", ["weight"] = 50}, {["ratio"] = "rf(2,2.5)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 4,
    },

    [14] = {
        attr = "res_mag_critical_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1.5)", ["weight"] = 50}, {["ratio"] = "rf(2,2.5)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 4,
    },

    [15] = {
        attr = "phy_defense",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 4,
    },

    [16] = {
        attr = "max_hp",
        attr_ratio = {{["ratio"] = "math.random(40,50)", ["weight"] = 30}, {["ratio"] = "math.random(50,60)", ["weight"] = 10}},
        pos = 4,
    },

    [17] = {
        attr = "res_seal_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 5,
    },

    [18] = {
        attr = "phy_defense",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 5,
    },

    [19] = {
        attr = "max_hp",
        attr_ratio = {{["ratio"] = "math.random(40,50)", ["weight"] = 30}, {["ratio"] = "math.random(50,60)", ["weight"] = 10}},
        pos = 5,
    },

    [20] = {
        attr = "res_seal_ratio",
        attr_ratio = {{["ratio"] = "rf(1,1)", ["weight"] = 50}, {["ratio"] = "rf(2,2)", ["weight"] = 45}, {["ratio"] = "rf(3,3)", ["weight"] = 5}},
        pos = 6,
    },

    [21] = {
        attr = "phy_defense",
        attr_ratio = {{["ratio"] = "math.random(20,30)", ["weight"] = 30}, {["ratio"] = "math.random(30,40)", ["weight"] = 10}},
        pos = 6,
    },

}
