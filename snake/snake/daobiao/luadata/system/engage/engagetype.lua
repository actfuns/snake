-- ./excel/system/engage/engagetype.xlsx
return {

    [1] = {
        cost = 12929,
        desc = [=[双方各得银戒指1个
可以举行中式普通婚礼]=],
        dissolve_mail = {4007, 4008},
        dissolve_silver = 100000,
        dissolve_silver2 = 50000,
        marry_sz = {{["sz"] = 7, ["role"] = 1}, {["sz"] = 8, ["role"] = 2}, {["sz"] = 9, ["role"] = 3}, {["sz"] = 10, ["role"] = 4}, {["sz"] = 11, ["role"] = 5}, {["sz"] = 12, ["role"] = 6}},
        pic_name = "中式结婚照",
        plot_id = 30,
        reward = {},
        reward_equip = 22901,
        send_xt_cnt = 20,
        success_mail = {4001, 4002},
        type = 1,
        wedding_name = "中式普通婚礼",
        wedding_sec = 22,
        xt_cnt = 20,
        yh_cnt = 5,
    },

    [2] = {
        cost = 12930,
        desc = [=[双方各得金戒指1个
双方各得5朵红玫瑰
订婚特权：铭刻爱情宣言
可以举行中式豪华婚礼]=],
        dissolve_mail = {4007, 4008},
        dissolve_silver = 100000,
        dissolve_silver2 = 50000,
        marry_sz = {{["sz"] = 7, ["role"] = 1}, {["sz"] = 8, ["role"] = 2}, {["sz"] = 9, ["role"] = 3}, {["sz"] = 10, ["role"] = 4}, {["sz"] = 11, ["role"] = 5}, {["sz"] = 12, ["role"] = 6}},
        pic_name = "中式结婚照",
        plot_id = 34,
        reward = {{["num"] = 5, ["sid"] = 10075}},
        reward_equip = 22902,
        send_xt_cnt = 30,
        success_mail = {4003, 4004},
        type = 2,
        wedding_name = "中式豪华婚礼",
        wedding_sec = 22,
        xt_cnt = 30,
        yh_cnt = 5,
    },

    [3] = {
        cost = 12931,
        desc = [=[双方各得钻石戒指1个
双方各得10朵红玫瑰
订婚特权：铭刻爱情宣言
500元宝红包1个（自动发放）
可以举行西式婚礼]=],
        dissolve_mail = {4007, 4008},
        dissolve_silver = 100000,
        dissolve_silver2 = 50000,
        marry_sz = {{["sz"] = 13, ["role"] = 1}, {["sz"] = 14, ["role"] = 2}, {["sz"] = 15, ["role"] = 3}, {["sz"] = 16, ["role"] = 4}, {["sz"] = 17, ["role"] = 5}, {["sz"] = 18, ["role"] = 6}},
        pic_name = "西式结婚照",
        plot_id = 33,
        reward = {{["num"] = 10, ["sid"] = 10075}},
        reward_equip = 22903,
        send_xt_cnt = 50,
        success_mail = {4005, 4006},
        type = 3,
        wedding_name = "西式婚礼",
        wedding_sec = 25,
        xt_cnt = 40,
        yh_cnt = 5,
    },

}
