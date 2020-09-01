-- ./excel/system/ride/other.xlsx
return {

    [1] = {
        clear_ratio = "100-95*cur_last/max_last",
        day_max_last = 80,
        forget_adv_cost = {{["cnt"] = 6, ["sid"] = 10197}},
        forget_base_cost = {{["cnt"] = 6, ["sid"] = 10197}},
        gradescore = "grade*50",
        id = 1,
        init_skill = {{["school"] = 1, ["skill"] = 5900}, {["school"] = 6, ["skill"] = 5900}, {["school"] = 3, ["skill"] = 5910}, {["school"] = 2, ["skill"] = 5930}, {["school"] = 4, ["skill"] = 5930}, {["school"] = 5, ["skill"] = 5920}},
        learn_cost = 2000,
        make_cost = 100000,
        pve_last = 1,
        pvp_last = 2,
        random_cost = {{["cnt"] = 3, ["sid"] = 10197}},
        reset_cost = {{["itemid"] = 11100, ["cnt"] = 1}},
        reset_exp_ratio = 80,
        reset_week_cnt = 99,
        upgrade_item = 11099,
    },

}
