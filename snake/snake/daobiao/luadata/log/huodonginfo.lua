-- ./excel/log/huodonginfo.xlsx
return {

    ["schoolpass"] = {
        explain = "门派试练",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "详细信息"}},
        subtype = "schoolpass",
    },

    ["campfire_give_tie"] = {
        explain = "篝火送情意结",
        log_format = {["giver"] = {["id"] = "giver", ["desc"] = "赠送者pid"}, ["giver_exp"] = {["id"] = "giver_exp", ["desc"] = "赠与者奖励经验"}, ["giver_gived_cnt"] = {["id"] = "giver_gived_cnt", ["desc"] = "赠与者赠与次数"}, ["isquick"] = {["id"] = "isquick", ["desc"] = "是否快捷赠送"}, ["receiver"] = {["id"] = "receiver", ["desc"] = "受赠者pid"}, ["receiver_exp"] = {["id"] = "receiver_exp", ["desc"] = "受赠者奖励经验"}, ["receiver_received_cnt"] = {["id"] = "receiver_received_cnt", ["desc"] = "受赠者受赠次数"}},
        subtype = "campfire_give_tie",
    },

    ["campfire_new_questions"] = {
        explain = "篝火生成新题目",
        log_format = {["ques_bench"] = {["id"] = "ques_bench", ["desc"] = "替补题对应关系"}, ["ques_list"] = {["id"] = "ques_list", ["desc"] = "题目序列"}},
        subtype = "campfire_new_questions",
    },

    ["hd_control_add"] = {
        explain = "增加活动控制",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "控制信息"}},
        subtype = "hd_control_add",
    },

    ["hd_control_del"] = {
        explain = "删除活动控制",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "控制信息"}},
        subtype = "hd_control_del",
    },

    ["hd_control_notify"] = {
        explain = "通知活动开启",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "控制信息"}, ["success"] = {["id"] = "success", ["desc"] = "是否成功"}},
        subtype = "hd_control_notify",
    },

    ["hd_taginfo"] = {
        explain = "活动页签同步",
        log_format = {["info"] = {["id"] = "info", ["desc"] = "也签信息"}},
        subtype = "hd_taginfo",
    },

}
