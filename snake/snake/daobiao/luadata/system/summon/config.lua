-- ./excel/system/summon/config.xlsx
return {

    [1] = {
        add_grow = {{["val"] = 1, ["weight"] = 80}, {["val"] = 2, ["weight"] = 20}},
        band_skill_cost = {["num"] = 1, ["sid"] = 11184},
        combine_max_aptitude = 100,
        combine_min_aptitude = 90,
        combine_xy_ratio = {{["grade"] = 0, ["ratio"] = 35}, {["grade"] = 55, ["ratio"] = 30}, {["grade"] = 65, ["ratio"] = 25}},
        combine_xy_ratio_new = 70,
        extend_ck_cost = {{["count"] = 750000, ["id"] = 2}, {["count"] = 1000000, ["id"] = 2}, {["count"] = 1250000, ["id"] = 2}, {["count"] = 1500000, ["id"] = 2}, {["count"] = 1750000, ["id"] = 2}, {["count"] = 2000000, ["id"] = 2}},
        extend_cost = {3, 4, 5, 6, 7},
        fight_count = {{["grade"] = 0, ["num"] = 3}, {["grade"] = 45, ["num"] = 4}, {["grade"] = 65, ["num"] = 5}, {["grade"] = 80, ["num"] = 6}},
        heigh_ratio = "math.min(30,(maxlv-minlv)//10*10)+50",
        new_weight = 10,
        re_combine_exp = 35,
        re_combine_skill = 30,
        use_grow_cnt = 5,
        wash_sep_cur_rate = 2,
        wash_sep_max_rate = {{["grade"] = 0, ["ratio"] = 3}, {["grade"] = 55, ["ratio"] = 3}, {["grade"] = 65, ["ratio"] = 2}},
        zp_aptitude = 87,
        zp_aptitude_rate = {{["grade"] = 0, ["ratio"] = 89}, {["grade"] = 55, ["ratio"] = 90}, {["grade"] = 65, ["ratio"] = 92}},
        zp_grow = 101,
        zp_skill_cnt = 6,
    },

}
